import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/map_tile_controls.dart';

class AdminAgentTrackerScreen extends StatefulWidget {
  const AdminAgentTrackerScreen({super.key});

  @override
  State<AdminAgentTrackerScreen> createState() =>
      _AdminAgentTrackerScreenState();
}

class _AdminAgentTrackerScreenState extends State<AdminAgentTrackerScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _geofences = [];
  List<Map<String, dynamic>> _routePlans = [];

  bool _isLoadingUsers = true;
  bool _isLoadingData = false;

  LatLng _getMapCenter() {
    if (_geofences.isNotEmpty) {
      final coords = _geofences.first['coordinates'];
      if (coords != null && coords is List && coords.isNotEmpty) {
        final lat = (coords[0]['lat'] as num?)?.toDouble();
        final lng = (coords[0]['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    }
    return const LatLng(-1.2921, 36.8219); // Default fallback (e.g. Nairobi)
  }

  List<CircleMarker> _buildGeofenceCircles() {
    List<CircleMarker> markers = [];
    for (var geo in _geofences) {
      final coords = geo['coordinates'];
      if (coords != null && coords is List && coords.isNotEmpty) {
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
                color: Colors.green.withValues(alpha: 0.3),
                borderColor: Colors.green,
                borderStrokeWidth: 2,
              ),
            );
          }
        }
      }
    }
    return markers;
  }

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      // Fetch all assignable users (excluding admins, where role == 1)
      final response = await _supabase
          .from('users')
          .select('id, full_name, email, role')
          .neq('role', 1);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _fetchAgentData(String userId) async {
    setState(() => _isLoadingData = true);
    try {
      // Fetch tasks targeted strictly to this user
      final tasksResponse = await _supabase
          .from('tasks')
          .select('*')
          .eq('assigned_to', userId)
          .order('due_at', ascending: true);

      // Fetch assigned geofences
      final geofencesResponse = await _supabase
          .from('geofences')
          .select('*')
          .eq('assigned_to', userId);

      // Fetch assigned route plans
      final routePlansResponse = await _supabase
          .from('route_plans')
          .select('*')
          .eq('assigned_to', userId)
          .order('route_date', ascending: true);

      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(tasksResponse);
          _geofences = List<Map<String, dynamic>>.from(geofencesResponse);
          _routePlans = List<Map<String, dynamic>>.from(routePlansResponse);
        });
      }
    } catch (e) {
      debugPrint('Error fetching agent data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Tracker')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                _isLoadingUsers
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Agent',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedUserId,
                      items:
                          _users.map((user) {
                            return DropdownMenuItem<String>(
                              value: user['id'].toString(),
                              child: Text(
                                user['full_name'] ??
                                    user['email'] ??
                                    'Unknown User',
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedUserId = val;
                        });
                        if (val != null) {
                          _fetchAgentData(val);
                        }
                      },
                    ),
          ),
          Expanded(
            child:
                _selectedUserId == null
                    ? const Center(
                      child: Text('Select an agent to view their data'),
                    )
                    : _isLoadingData
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        const Text(
                          'Assigned Tasks & Route Plans',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_tasks.isEmpty) const Text('No tasks assigned.'),
                        ..._tasks.map((task) {
                          DateTime? dueAt =
                              task['due_at'] != null
                                  ? DateTime.tryParse(task['due_at'])
                                  : null;
                          String dateStr =
                              dueAt != null
                                  ? dueAt.toLocal().toString().split(' ')[0]
                                  : 'No date';
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.route,
                                color: Colors.blue,
                              ),
                              title: Text(task['title'] ?? 'No Title'),
                              subtitle: Text(
                                task['description'] ?? 'No Description',
                              ),
                              trailing: Text(
                                dateStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        const Text(
                          'Assigned Geofences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_geofences.isEmpty)
                          const Text('No geofences assigned.'),
                        if (_geofences.isNotEmpty) ...[
                          SizedBox(
                            height: 250,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FlutterMap(
                                key: ValueKey(_selectedUserId),
                                options: MapOptions(
                                  initialCenter: _getMapCenter(),
                                  initialZoom: 12.0,
                                ),
                                children: [
                                  MapTileLayer(
                                    userAgentPackageName: 'com.longhorn.dehus',
                                  ),
                                  CircleLayer(circles: _buildGeofenceCircles()),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ..._geofences.map(
                          (geo) => Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.map,
                                color: Colors.green,
                              ),
                              title: Text(geo['name'] ?? 'Unnamed Geofence'),
                              subtitle: Text(geo['description'] ?? ''),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Route Plans of the Day',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_routePlans.isEmpty)
                          const Text('No route plans assigned.'),
                        ..._routePlans.map((routePlan) {
                          final routeDate =
                              routePlan['route_date']?.toString() ?? '';
                          final routeSchools =
                              routePlan['school_ids'] is List
                                  ? (routePlan['school_ids'] as List).length
                                  : 0;
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.route,
                                color: Colors.orange,
                              ),
                              title: Text(routePlan['title'] ?? 'Route Plan'),
                              subtitle: Text(
                                '${routePlan['notes'] ?? 'No notes'}\nRoute date: $routeDate',
                              ),
                              trailing: Text(
                                '$routeSchools stops',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
