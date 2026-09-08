import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';
import '../../core/widgets/map_tile_controls.dart';

class AdminGeofenceMapScreen extends StatefulWidget {
  const AdminGeofenceMapScreen({super.key});

  @override
  State<AdminGeofenceMapScreen> createState() => _AdminGeofenceMapScreenState();
}

class _AdminGeofenceMapScreenState extends State<AdminGeofenceMapScreen> {
  final _supabase = Supabase.instance.client;
  final _dbService = DatabaseService();
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  int _selectedRoleFilter = 4;
  List<Map<String, dynamic>> _existingGeofences = [];
  List<Map<String, dynamic>> _schools = [];
  String? _selectedUserId;
  String? _selectedCountyFilter;
  bool _isLoadingUsers = true;
  bool _isMapReady = false;
  bool _showControlPanel = false;

  // Geofence states
  LatLng? _selectedLocation;
  double _geofenceRadiusMeters = 500.0;

  // Default start location (e.g., center of a relevant city/country)
  static const LatLng _initialCenter = LatLng(
    -1.2921,
    36.8219,
  ); // Nairobi, Kenya

  static const List<String> _kenyaCounties = [
    'Baringo',
    'Bomet',
    'Bungoma',
    'Busia',
    'Elgeyo-Marakwet',
    'Embu',
    'Garissa',
    'Homa Bay',
    'Isiolo',
    'Kajiado',
    'Kakamega',
    'Kericho',
    'Kiambu',
    'Kilifi',
    'Kirinyaga',
    'Kisii',
    'Kisumu',
    'Kitui',
    'Kwale',
    'Laikipia',
    'Lamu',
    'Machakos',
    'Makueni',
    'Mandera',
    'Marsabit',
    'Meru',
    'Migori',
    'Mombasa',
    'Murang\'a',
    'Nairobi',
    'Nakuru',
    'Nandi',
    'Narok',
    'Nyamira',
    'Nyandarua',
    'Nyeri',
    'Samburu',
    'Siaya',
    'Taita-Taveta',
    'Tana River',
    'Tharaka-Nithi',
    'Trans Nzoia',
    'Turkana',
    'Uasin Gishu',
    'Vihiga',
    'Wajir',
    'West Pokot',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch all non-admin users to populate the dropdown
      final usersResponse = await _supabase
          .from('users')
          .select('id, full_name, email, role, region')
          .neq('role', 1);

      // Fetch existing geofences to display on the map
      final geofencesResponse = await _supabase.from('geofences').select('*');
      final schoolsResponse = await _supabase
          .from('schools')
          .select('id, county, latitude, longitude');

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersResponse);
          _filterUsers();
          _existingGeofences = List<Map<String, dynamic>>.from(
            geofencesResponse,
          );
          _schools = List<Map<String, dynamic>>.from(schoolsResponse);
          _isLoadingUsers = false;
        });
        _zoomToSelectedCountyGeofences();
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _filterUsers() {
    _filteredUsers =
        _users.where((u) {
          final hasRole = u['role'] == _selectedRoleFilter;
          if (!hasRole) return false;
          if (_selectedCountyFilter == null ||
              _selectedCountyFilter!.trim().isEmpty) {
            return true;
          }
          final region = (u['region'] ?? '').toString().trim().toLowerCase();
          return region == _selectedCountyFilter!.toLowerCase();
        }).toList();
    if (!_filteredUsers.any((u) => u['id'].toString() == _selectedUserId)) {
      _selectedUserId = null;
    }
  }

  Color _countyColor(String? county) {
    final normalized = (county ?? '').trim();
    if (normalized.isEmpty) return Colors.grey;
    final index = _kenyaCounties.indexWhere(
      (c) => c.toLowerCase() == normalized.toLowerCase(),
    );
    final safe = index >= 0 ? index : normalized.hashCode.abs() % 47;
    return Colors.primaries[safe % Colors.primaries.length];
  }

  bool _geofenceMatchesCounty(Map<String, dynamic> geo) {
    if (_selectedCountyFilter == null ||
        _selectedCountyFilter!.trim().isEmpty) {
      return true;
    }
    final selected = _selectedCountyFilter!.toLowerCase();
    final geoCounty = (geo['region'] ?? '').toString().trim().toLowerCase();
    if (geoCounty == selected) return true;

    // Fallback: infer county from assigned user's region when geofence.region is missing.
    final assignedTo = geo['assigned_to']?.toString();
    if (assignedTo == null || assignedTo.isEmpty) return false;
    final matchedUser = _users.cast<Map<String, dynamic>?>().firstWhere(
      (u) => u?['id']?.toString() == assignedTo,
      orElse: () => null,
    );
    if (matchedUser == null) return false;
    final userRegion =
        (matchedUser['region'] ?? '').toString().trim().toLowerCase();
    return userRegion == selected;
  }

  List<CircleMarker> _buildExistingGeofenceCircles() {
    List<CircleMarker> markers = [];
    for (var geo in _existingGeofences) {
      final county = geo['region']?.toString();
      if (!_geofenceMatchesCounty(geo)) continue;
      final coords = geo['coordinates'];
      if (coords != null && coords is List && coords.isNotEmpty) {
        final countyColor = _countyColor(county);
        for (var point in coords) {
          final lat = (point['lat'] as num?)?.toDouble();
          final lng = (point['lng'] as num?)?.toDouble();
          final radius = (point['radius'] as num?)?.toDouble();
          if (lat != null && lng != null && radius != null) {
            markers.add(
              CircleMarker(
                point: LatLng(lat, lng),
                radius: radius,
                useRadiusInMeter: true,
                color: countyColor.withValues(alpha: 0.22),
                borderColor: countyColor,
                borderStrokeWidth: 3,
              ),
            );
          }
        }
      }
    }
    return markers;
  }

  List<Marker> _buildCountyLabels() {
    final labels = <Marker>[];
    for (final geo in _existingGeofences) {
      final county = geo['region']?.toString();
      if (!_geofenceMatchesCounty(geo)) continue;
      final coords = geo['coordinates'];
      if (coords is List && coords.isNotEmpty) {
        final first = coords.first;
        if (first is Map) {
          final mapFirst = Map<String, dynamic>.from(first);
          final lat = (mapFirst['lat'] as num?)?.toDouble();
          final lng = (mapFirst['lng'] as num?)?.toDouble();
          if (lat != null && lng != null && (county ?? '').trim().isNotEmpty) {
            labels.add(
              Marker(
                point: LatLng(lat, lng),
                width: 130,
                height: 28,
                child: IgnorePointer(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _countyColor(county), width: 2),
                    ),
                    child: Text(
                      county!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
      }
    }
    return labels;
  }

  List<LatLng> _countyAreaPoints() {
    if (_selectedCountyFilter == null ||
        _selectedCountyFilter!.trim().isEmpty) {
      return const [];
    }
    final selected = _selectedCountyFilter!.toLowerCase();
    final points = <LatLng>[];

    for (final geo in _existingGeofences) {
      if (!_geofenceMatchesCounty(geo)) continue;
      final coords = geo['coordinates'];
      if (coords is List) {
        for (final point in coords) {
          if (point is Map) {
            final mapPoint = Map<String, dynamic>.from(point);
            final lat = (mapPoint['lat'] as num?)?.toDouble();
            final lng = (mapPoint['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              points.add(LatLng(lat, lng));
            }
          }
        }
      }
    }

    for (final school in _schools) {
      final county = (school['county'] ?? '').toString().trim().toLowerCase();
      if (county != selected) continue;
      final lat = (school['latitude'] as num?)?.toDouble();
      final lng = (school['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    return points;
  }

  List<LatLng> _countyBoundaryPolygon() {
    final points = _countyAreaPoints();
    if (points.isEmpty) return const [];

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    const latPad = 0.03;
    const lngPad = 0.03;

    return [
      LatLng(minLat - latPad, minLng - lngPad),
      LatLng(minLat - latPad, maxLng + lngPad),
      LatLng(maxLat + latPad, maxLng + lngPad),
      LatLng(maxLat + latPad, minLng - lngPad),
    ];
  }

  void _zoomToSelectedCountyGeofences() {
    if (!_isMapReady) return;
    if (_selectedCountyFilter == null ||
        _selectedCountyFilter!.trim().isEmpty) {
      return;
    }

    final points = _countyAreaPoints();

    if (points.isEmpty) {
      _mapController.move(_initialCenter, 6);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No geofence/school coordinates found in $_selectedCountyFilter.',
            ),
          ),
        );
      }
      return;
    }
    if (points.length == 1) {
      _mapController.move(points.first, 12);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        14.0, // Zoom in closer to the admin's location
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMapTapped(TapPosition _, LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  Future<void> _assignGeofenceTask() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to set a geofence center.'),
        ),
      );
      return;
    }

    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user to assign this area to.'),
        ),
      );
      return;
    }

    try {
      await _dbService.insertWithOfflineQueue(
        table: 'geofences',
        payload: {
          'name': 'Cover Geofenced Area',
          'description': 'Please cover the assigned geographic area.',
          'assigned_to': _selectedUserId,
          'region': _selectedCountyFilter,
          'coordinates': [
            {
              'lat': _selectedLocation!.latitude,
              'lng': _selectedLocation!.longitude,
              'radius': _geofenceRadiusMeters,
            },
          ],
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geofence assigned successfully!')),
        );
        setState(() {
          _selectedLocation = null;
          _selectedUserId = null;
        });
        _fetchData(); // Refresh map with the new geofence
      }
    } catch (e) {
      debugPrint('Error assigning geofence: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final mapContent = Stack(
      children: [
        // Full screen map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 12.0,
            minZoom: 2,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _isMapReady = true;
              _centerOnCurrentLocation();
              _zoomToSelectedCountyGeofences();
            },
            onTap: _onMapTapped,
          ),
          children: [
            MapTileLayer(
              userAgentPackageName: 'com.longhorn.dehus',
              maxNativeZoom: 19,
              panBuffer: 2,
            ),
            CircleLayer(
              circles: [
                ..._buildExistingGeofenceCircles(),
                if (_selectedLocation != null)
                  CircleMarker(
                    point: _selectedLocation!,
                    radius: _geofenceRadiusMeters,
                    useRadiusInMeter: true,
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                  ),
              ],
            ),
            if (_selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            MarkerLayer(markers: _buildCountyLabels()),
            if (_selectedCountyFilter != null &&
                _selectedCountyFilter!.trim().isNotEmpty &&
                _countyBoundaryPolygon().isNotEmpty)
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _countyBoundaryPolygon(),
                    color: _countyColor(
                      _selectedCountyFilter,
                    ).withValues(alpha: 0.12),
                    borderColor: _countyColor(_selectedCountyFilter),
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
          ],
        ),

        // Custom location button since FlutterMap doesn't include one by default
        if (_selectedCountyFilter != null &&
            _selectedCountyFilter!.trim().isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _countyColor(_selectedCountyFilter),
                  width: 2,
                ),
              ),
              child: Text(
                'County: $_selectedCountyFilter',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'geofence_fullscreen',
            backgroundColor: const Color(0xFF6D273F),
            onPressed: _openFullScreenMap,
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            label: const Text(
              'Full Screen',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _centerOnCurrentLocation,
            child: const Icon(Icons.my_location, color: Colors.black87),
          ),
        ),
      ],
    );

    final controlPanel = Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '1. Tap the map to select a location',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text('2. Adjust Radius: ${_geofenceRadiusMeters.toInt()}m'),
          Slider(
            value: _geofenceRadiusMeters,
            min: 100,
            max: 5000,
            divisions: 49,
            label: '${_geofenceRadiusMeters.toInt()}m',
            onChanged: (value) {
              setState(() {
                _geofenceRadiusMeters = value;
              });
            },
          ),
          const SizedBox(height: 8),
          const Text(
            '3. Select User to Tag',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Role:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedRoleFilter,
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('Manager (Role 2)')),
                    DropdownMenuItem(value: 3, child: Text('BAS (Role 3)')),
                    DropdownMenuItem(value: 4, child: Text('Agent (Role 4)')),
                    DropdownMenuItem(value: 5, child: Text('Grounds (Role 5)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRoleFilter = val;
                        _filterUsers();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'County (Kenya)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            initialValue: _selectedCountyFilter,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All counties'),
              ),
              ..._kenyaCounties.map(
                (county) => DropdownMenuItem<String>(
                  value: county,
                  child: Text(county),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCountyFilter = value;
                _filterUsers();
              });
              _zoomToSelectedCountyGeofences();
            },
          ),
          const SizedBox(height: 8),
          _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: const Text('Choose a user...'),
                initialValue: _selectedUserId,
                items:
                    _filteredUsers.map((user) {
                      return DropdownMenuItem<String>(
                        value: user['id'].toString(),
                        child: Text(
                          '${user['full_name'] ?? user['email'] ?? 'Unknown User'}'
                          '${(user['region'] ?? '').toString().trim().isNotEmpty ? ' (${user['region']})' : ''}',
                        ),
                      );
                    }).toList(),
                onChanged: (val) => setState(() => _selectedUserId = val),
              ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _assignGeofenceTask,
            child: const Text('Tag User & Assign Geofence'),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Geofence')),
      body:
          isDesktop
              ? Column(
                children: [
                  Expanded(child: mapContent),
                  SizedBox(
                    height: 300,
                    child: SingleChildScrollView(child: controlPanel),
                  ),
                ],
              )
              : Stack(
                children: [
                  mapContent,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showControlPanel = !_showControlPanel;
                                  });
                                },
                                icon: Icon(
                                  _showControlPanel
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                ),
                                label: Text(
                                  _showControlPanel
                                      ? 'Hide Geofence Controls'
                                      : 'Show Geofence Controls',
                                ),
                              ),
                            ),
                          ),
                          if (_showControlPanel)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.38,
                              ),
                              child: SingleChildScrollView(child: controlPanel),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  void _openFullScreenMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => _AdminGeofenceFullScreenMapPage(
              initialCenter: _initialCenter,
              existingGeofenceCircles: _buildExistingGeofenceCircles(),
              countyLabels: _buildCountyLabels(),
              countyBoundaryPolygon: _countyBoundaryPolygon(),
              countyColor: _countyColor(_selectedCountyFilter),
              selectedCountyFilter: _selectedCountyFilter,
              selectedLocation: _selectedLocation,
              geofenceRadiusMeters: _geofenceRadiusMeters,
            ),
      ),
    );
  }
}

class _AdminGeofenceFullScreenMapPage extends StatelessWidget {
  const _AdminGeofenceFullScreenMapPage({
    required this.initialCenter,
    required this.existingGeofenceCircles,
    required this.countyLabels,
    required this.countyBoundaryPolygon,
    required this.countyColor,
    required this.selectedCountyFilter,
    required this.selectedLocation,
    required this.geofenceRadiusMeters,
  });

  final LatLng initialCenter;
  final List<CircleMarker> existingGeofenceCircles;
  final List<Marker> countyLabels;
  final List<LatLng> countyBoundaryPolygon;
  final Color countyColor;
  final String? selectedCountyFilter;
  final LatLng? selectedLocation;
  final double geofenceRadiusMeters;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Map - Full Screen')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 12.0,
          minZoom: 2,
          maxZoom: 18,
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
          CircleLayer(
            circles: [
              ...existingGeofenceCircles,
              if (selectedLocation != null)
                CircleMarker(
                  point: selectedLocation!,
                  radius: geofenceRadiusMeters,
                  useRadiusInMeter: true,
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderColor: Colors.blue,
                  borderStrokeWidth: 2,
                ),
            ],
          ),
          if (selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
          MarkerLayer(markers: countyLabels),
          if (selectedCountyFilter != null &&
              selectedCountyFilter!.trim().isNotEmpty &&
              countyBoundaryPolygon.isNotEmpty)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: countyBoundaryPolygon,
                  color: countyColor.withValues(alpha: 0.12),
                  borderColor: countyColor,
                  borderStrokeWidth: 3,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
