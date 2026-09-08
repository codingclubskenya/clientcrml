import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/map_tile_controls.dart';

class BasAlertsPage extends StatefulWidget {
  const BasAlertsPage({super.key});

  @override
  State<BasAlertsPage> createState() => _BasAlertsPageState();
}

class _BasAlertsPageState extends State<BasAlertsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _routePlans = [];
  List<Map<String, dynamic>> _geofences = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You must be signed in to view BAS alerts.';
      });
      return;
    }

    try {
      Future<_AlertsData> fetchAlertsFor(String userId) async {
        final routePlansResponse = await _supabase
            .from('route_plans')
            .select('*')
            .eq('assigned_to', userId)
            .order('route_date', ascending: true);

        final geofencesResponse = await _supabase
            .from('geofences')
            .select('*')
            .eq('assigned_to', userId);

        final tasksResponse = await _supabase
            .from('tasks')
            .select('*')
            .eq('assigned_to', userId)
            .order('due_at', ascending: true);

        final routePlans = List<Map<String, dynamic>>.from(routePlansResponse);
        final schoolIds = <String>{};
        for (final routePlan in routePlans) {
          final rawSchoolIds = routePlan['school_ids'];
          if (rawSchoolIds is List) {
            schoolIds.addAll(rawSchoolIds.map((value) => value.toString()));
          }
        }

        List<Map<String, dynamic>> schools = [];
        if (schoolIds.isNotEmpty) {
          final schoolsResponse = await _supabase
              .from('schools')
              .select(
                'id, name, county, phone, latitude, longitude, book_category',
              )
              .inFilter('id', schoolIds.toList());
          schools = List<Map<String, dynamic>>.from(schoolsResponse);
        }

        return _AlertsData(
          routePlans: routePlans,
          geofences: List<Map<String, dynamic>>.from(geofencesResponse),
          tasks: List<Map<String, dynamic>>.from(tasksResponse),
          schools: schools,
        );
      }

      final alertsData = await fetchAlertsFor(currentUser.id);

      if (!mounted) return;
      setState(() {
        _routePlans = alertsData.routePlans;
        _geofences = alertsData.geofences;
        _tasks = alertsData.tasks;
        _schools = alertsData.schools;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load BAS alerts: $e';
      });
    }
  }

  List<CircleMarker> _buildGeofenceCircles() {
    final circles = <CircleMarker>[];
    for (final geofence in _geofences) {
      final coords = geofence['coordinates'];
      if (coords is List) {
        for (final point in coords) {
          if (point is Map<String, dynamic>) {
            final lat = (point['lat'] as num?)?.toDouble();
            final lng = (point['lng'] as num?)?.toDouble();
            final radius = (point['radius'] as num?)?.toDouble();
            if (lat != null && lng != null && radius != null) {
              circles.add(
                CircleMarker(
                  point: LatLng(lat, lng),
                  radius: radius,
                  useRadiusInMeter: true,
                  color: Colors.green.withValues(alpha: 0.25),
                  borderColor: Colors.green.shade700,
                  borderStrokeWidth: 2,
                ),
              );
            }
          }
        }
      }
    }
    return circles;
  }

  List<LatLng> _buildRoutePolylinePoints() {
    final routePlan = _routePlans.isNotEmpty ? _routePlans.first : null;
    if (routePlan == null) return const [];

    final rawSchoolIds = routePlan['school_ids'];
    if (rawSchoolIds is! List || rawSchoolIds.isEmpty) return const [];

    final orderedPoints = <LatLng>[];
    for (final schoolId in rawSchoolIds) {
      final school = _schools.cast<Map<String, dynamic>>().firstWhere(
        (school) => school['id'].toString() == schoolId.toString(),
        orElse: () => <String, dynamic>{},
      );
      final lat = (school['latitude'] as num?)?.toDouble();
      final lng = (school['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        orderedPoints.add(LatLng(lat, lng));
      }
    }
    return orderedPoints;
  }

  LatLng _mapCenter() {
    final routePoints = _buildRoutePolylinePoints();
    if (routePoints.isNotEmpty) return routePoints.first;

    for (final school in _schools) {
      final lat = (school['latitude'] as num?)?.toDouble();
      final lng = (school['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }

    if (_geofences.isNotEmpty) {
      final coords = _geofences.first['coordinates'];
      if (coords is List && coords.isNotEmpty) {
        final point = coords.first;
        if (point is Map<String, dynamic>) {
          final lat = (point['lat'] as num?)?.toDouble();
          final lng = (point['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) return LatLng(lat, lng);
        }
      }
    }

    return const LatLng(-1.2921, 36.8219);
  }

  String _formatDate(dynamic value) {
    final parsed =
        value is String ? DateTime.tryParse(value) : value as DateTime?;
    if (parsed == null) return 'No date';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1100;
                    final isTablet = constraints.maxWidth >= 760;
                    final padding = isTablet ? 20.0 : 12.0;
                    final mapHeight =
                        isWide ? 500.0 : (isTablet ? 420.0 : 300.0);

                    if (isWide) {
                      return ListView(
                        padding: EdgeInsets.all(padding),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildSummaryCard(),
                                    const SizedBox(height: 16),
                                    _buildMapCard(mapHeight),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildRoutePlanCard(),
                                    const SizedBox(height: 16),
                                    _buildGeofenceListCard(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return ListView(
                      padding: EdgeInsets.all(padding),
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildMapCard(mapHeight),
                        const SizedBox(height: 16),
                        _buildRoutePlanCard(),
                        const SizedBox(height: 16),
                        _buildGeofenceListCard(),
                      ],
                    );
                  },
                ),
              ),
    );
  }

  Widget _buildSummaryCard() {
    final routePlan = _routePlans.isNotEmpty ? _routePlans.first : null;
    final geofenceCount = _geofences.length;
    final taskCount = _tasks.length;

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today\'s Route Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(routePlan?['title'] ?? 'No route plan assigned yet.'),
            const SizedBox(height: 8),
            Text(
              'Route date: ${routePlan == null ? 'No date' : _formatDate(routePlan['route_date'])}',
            ),
            Text('Geofences assigned: $geofenceCount'),
            Text('Tasks assigned: $taskCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(double mapHeight) {
    final routePoints = _buildRoutePolylinePoints();
    final center = _mapCenter();

    final markers = <Marker>[
      ..._schools.map((school) {
        final lat = (school['latitude'] as num?)?.toDouble();
        final lng = (school['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return null;
        return Marker(
          point: LatLng(lat, lng),
          width: 42,
          height: 42,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 38),
        );
      }).whereType<Marker>(),
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Map',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 11.5,
                          minZoom: 2,
                          maxZoom: 19,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          MapTileLayer(
                            userAgentPackageName: 'com.longhorn.dehus',
                            maxNativeZoom: 19,
                            panBuffer: 2,
                          ),
                          CircleLayer(circles: _buildGeofenceCircles()),
                          if (routePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  strokeWidth: 4,
                                  color: Colors.orange,
                                ),
                              ],
                            ),
                          if (markers.isNotEmpty) MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => _BasAlertsFullScreenMapPage(
                                  center: center,
                                  geofenceCircles: _buildGeofenceCircles(),
                                  routePoints: routePoints,
                                  markers: markers,
                                ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.fullscreen, size: 18),
                      label: const Text('Full Screen'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6D273F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePlanCard() {
    if (_routePlans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No route plan assigned to you yet.'),
        ),
      );
    }

    final routePlan = _routePlans.first;
    final rawSchoolIds = routePlan['school_ids'];
    final schoolIdList =
        rawSchoolIds is List
            ? rawSchoolIds.map((e) => e.toString()).toList()
            : <String>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Plan of the Day',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(routePlan['title'] ?? 'Route Plan'),
            Text('Status: ${routePlan['status'] ?? 'assigned'}'),
            Text('Stops: ${schoolIdList.length}'),
            const SizedBox(height: 12),
            ...schoolIdList.asMap().entries.map((entry) {
              final school = _schools.cast<Map<String, dynamic>>().firstWhere(
                (school) => school['id'].toString() == entry.value,
                orElse: () => <String, dynamic>{},
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text('${entry.key + 1}'),
                ),
                title: Text(school['name'] ?? 'Unknown School'),
                subtitle: Text(
                  '${school['county'] ?? 'No county'} • ${school['book_category'] ?? 'No SOP'}',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceListCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned Geofences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_geofences.isEmpty)
              const Text('No geofences have been assigned yet.'),
            ..._geofences.map(
              (geofence) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.map, color: Colors.green),
                title: Text(geofence['name'] ?? 'Unnamed geofence'),
                subtitle: Text(geofence['description'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsData {
  const _AlertsData({
    required this.routePlans,
    required this.geofences,
    required this.tasks,
    required this.schools,
  });

  final List<Map<String, dynamic>> routePlans;
  final List<Map<String, dynamic>> geofences;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> schools;
}

class _BasAlertsFullScreenMapPage extends StatelessWidget {
  const _BasAlertsFullScreenMapPage({
    required this.center,
    required this.geofenceCircles,
    required this.routePoints,
    required this.markers,
  });

  final LatLng center;
  final List<CircleMarker> geofenceCircles;
  final List<LatLng> routePoints;
  final List<Marker> markers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Map - Full Screen')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 11.5,
          minZoom: 2,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          MapTileLayer(
            userAgentPackageName: 'com.longhorn.dehus',
            maxNativeZoom: 19,
            panBuffer: 2,
          ),
          CircleLayer(circles: geofenceCircles),
          if (routePoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4,
                  color: Colors.orange,
                ),
              ],
            ),
          if (markers.isNotEmpty) MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
