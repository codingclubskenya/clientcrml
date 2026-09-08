import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../models/farmer_model.dart';
import '../database/database_service.dart';
import '../../core/widgets/map_tile_controls.dart';

class Role2RoutePlanPage extends StatefulWidget {
  const Role2RoutePlanPage({super.key});

  @override
  State<Role2RoutePlanPage> createState() => _Role2RoutePlanPageState();
}

class _Role2RoutePlanPageState extends State<Role2RoutePlanPage> {
  final _supabase = Supabase.instance.client;
  final _dbService = DatabaseService();
  final _schoolSearchController = TextEditingController();

  bool _isLoading = true;
  String? _selectedAgentId;
  DateTime? _selectedDate;

  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _schools = [];
  final List<String> _selectedSchoolIds = [];
  Map<String, String> _stageBySchoolId = {};
  List<String> _availableStages = [];
  String _selectedCounty = 'All Counties';
  String _schoolSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _schoolSearchController.addListener(() {
      setState(() => _schoolSearchQuery = _schoolSearchController.text.trim());
    });
  }

  @override
  void dispose() {
    _schoolSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final usersResponse = await _supabase
          .from('users')
          .select('id, full_name, email, role')
          .eq('role', 5)
          .order('full_name', ascending: true);
      final schoolModels = await _dbService.getAllSchools();
      final localSchools =
          schoolModels
              .map(
                (SchoolModel s) => <String, dynamic>{
                  'id': s.id,
                  'name': s.name,
                  'county': s.county,
                  'latitude': s.latitude,
                  'longitude': s.longitude,
                  'school_lifecycle_status': s.schoolLifecycleStatus,
                  'engagement_type': s.engagementType,
                },
              )
              .toList()
            ..sort(
              (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              ),
            );
      final remoteSchools = await _fetchAllSchoolsFromSupabase();
      final localById = {
        for (final school in localSchools)
          (school['id'] ?? '').toString(): school,
      };
      for (final remote in remoteSchools) {
        final id = (remote['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final existing = localById[id];
        if (existing == null) {
          localById[id] = remote;
          continue;
        }
        if (_toDouble(remote['latitude']) != null) {
          existing['latitude'] = remote['latitude'];
        }
        if (_toDouble(remote['longitude']) != null) {
          existing['longitude'] = remote['longitude'];
        }
      }
      final schoolsResponse =
          localById.values.toList()..sort(
            (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
              (b['name'] ?? '').toString().toLowerCase(),
            ),
          );
      final salesResponse = await _supabase
          .from('school_sales')
          .select('school_id, sale_status, stage_updated_at, created_at')
          .order('stage_updated_at', ascending: false);

      final stageMap = <String, String>{};
      final discoveredStages = <String>{};
      for (final row in List<Map<String, dynamic>>.from(salesResponse)) {
        final schoolId = (row['school_id']?.toString() ?? '').trim();
        final stage = (row['sale_status']?.toString() ?? '').trim();
        if (schoolId.isEmpty || stage.isEmpty) continue;
        final normalized = _normalizeStage(stage);
        stageMap.putIfAbsent(schoolId, () => normalized);
        discoveredStages.add(normalized);
      }
      for (final school in List<Map<String, dynamic>>.from(schoolsResponse)) {
        final lifecycle = (school['school_lifecycle_status'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll(' ', '_');
        if (lifecycle.isNotEmpty) {
          discoveredStages.add(lifecycle);
        }
      }

      if (!mounted) return;
      setState(() {
        _agents = List<Map<String, dynamic>>.from(usersResponse);
        _schools = List<Map<String, dynamic>>.from(schoolsResponse);
        _stageBySchoolId = stageMap;
        _availableStages = discoveredStages.toList()..sort();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed loading route data: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllSchoolsFromSupabase() async {
    const pageSize = 1000;
    var from = 0;
    final all = <Map<String, dynamic>>[];

    while (true) {
      final response = await _supabase
          .from('schools')
          .select(
            'id, name, county, latitude, longitude, school_lifecycle_status, engagement_type',
          )
          .range(from, from + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      if (page.isEmpty) break;
      all.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }

    return all;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _createRoutePlan() async {
    if (_selectedAgentId == null || _selectedAgentId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a Field Agent.')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick a route date.')));
      return;
    }
    if (_selectedSchoolIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one school stop.')),
      );
      return;
    }

    try {
      final routeDate = _selectedDate!.toIso8601String().split('T').first;
      final selectedSchools =
          _selectedSchoolIds.map((id) {
            return _schools.firstWhere((s) => s['id'].toString() == id);
          }).toList();

      for (var i = 0; i < selectedSchools.length; i++) {
        final school = selectedSchools[i];
        await _dbService.insertWithOfflineQueue(
          table: 'tasks',
          payload: {
            'title': 'Visit ${school['name'] ?? 'School'}',
            'description': 'Route stop ${i + 1} for $routeDate',
            'target_role': 5,
            'assigned_to': _selectedAgentId,
            'due_at': _selectedDate!.toIso8601String(),
          },
        );
      }

      await _dbService.insertWithOfflineQueue(
        table: 'route_plans',
        payload: {
          'title': 'Route Plan $routeDate',
          'route_date': routeDate,
          'assigned_to': _selectedAgentId,
          'school_ids': _selectedSchoolIds,
          'notes':
              'Planned stops: ${selectedSchools.map((s) => s['name']).join(', ')}',
          'status': 'assigned',
          'created_by': _supabase.auth.currentUser?.id,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route plan created successfully.')),
      );

      setState(() {
        _selectedSchoolIds.clear();
        _selectedDate = null;
        _schoolSearchController.clear();
      });

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create route: $e')));
    }
  }

  List<LatLng> _selectedRoutePoints() {
    final points = <LatLng>[];
    for (final schoolId in _selectedSchoolIds) {
      final school = _schools.firstWhere(
        (s) => s['id'].toString() == schoolId,
        orElse: () => <String, dynamic>{},
      );
      final lat = _toDouble(school['latitude']);
      final lng = _toDouble(school['longitude']);
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }
    return points;
  }

  List<String> get _countyFilters {
    final counties =
        _schools
            .map((s) => (s['county'] ?? '').toString().trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Counties', ...counties];
  }

  List<Map<String, dynamic>> get _visibleSchools {
    List<Map<String, dynamic>> schools = _schools;
    if (_selectedCounty != 'All Counties') {
      schools =
          schools.where((school) {
            final county =
                (school['county'] ?? '').toString().trim().toLowerCase();
            return county == _selectedCounty.toLowerCase();
          }).toList();
    }
    if (_schoolSearchQuery.isNotEmpty) {
      final q = _schoolSearchQuery.toLowerCase();
      schools =
          schools.where((s) {
            final name = (s['name'] ?? '').toString().toLowerCase();
            return name.contains(q);
          }).toList();
    }
    return schools;
  }

  List<Map<String, dynamic>> get _visibleSchoolsMissingGps {
    return _visibleSchools.where((school) {
      final lat = _toDouble(school['latitude']);
      final lng = _toDouble(school['longitude']);
      return lat == null || lng == null;
    }).toList();
  }

  LatLng _defaultMapCenter() {
    for (final school in _visibleSchools) {
      final lat = _toDouble(school['latitude']);
      final lng = _toDouble(school['longitude']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    for (final school in _schools) {
      final lat = _toDouble(school['latitude']);
      final lng = _toDouble(school['longitude']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return const LatLng(-1.2921, 36.8219);
  }

  void _toggleSchool(String schoolId, bool checked) {
    setState(() {
      if (checked) {
        if (!_selectedSchoolIds.contains(schoolId)) {
          _selectedSchoolIds.add(schoolId);
        }
      } else {
        _selectedSchoolIds.remove(schoolId);
      }
    });
  }

  String _stageLabel(String stage) {
    if (stage.isEmpty) return 'No Stage';
    return stage
        .split('_')
        .map(
          (part) =>
              part.isEmpty
                  ? part
                  : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _schoolStage(Map<String, dynamic> school) {
    final schoolId = (school['id']?.toString() ?? '').trim();
    final salesStage = _stageBySchoolId[schoolId];
    if (salesStage != null && salesStage.isNotEmpty) return salesStage;
    final lifecycle = (school['school_lifecycle_status']?.toString().trim() ??
            '')
        .toLowerCase()
        .replaceAll(' ', '_');
    if (lifecycle.isNotEmpty) return lifecycle;
    final engagement = (school['engagement_type']?.toString().trim() ?? '')
        .toLowerCase()
        .replaceAll(' ', '_');
    return engagement;
  }

  String _normalizeStage(String stage) {
    return stage.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  Color _stageColor(String stage) {
    final normalized = _normalizeStage(stage);
    if (normalized.isEmpty) return Colors.grey;
    switch (normalized) {
      case 'lead':
        return Colors.blue;
      case 'prospecting':
        return Colors.indigo;
      case 'contacted':
        return Colors.teal;
      case 'meeting_scheduled':
        return Colors.cyan.shade700;
      case 'proposal_sent':
        return Colors.amber.shade700;
      case 'negotiation':
        return Colors.deepOrange;
      case 'won':
      case 'closed_won':
        return Colors.green;
      case 'lost':
      case 'closed_lost':
        return Colors.red;
      default:
        final hash = normalized.hashCode;
        final hue = (hash % 360).toDouble();
        return HSVColor.fromAHSV(1, hue, 0.65, 0.8).toColor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role 2 Route Planner'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;
                  final isTablet = constraints.maxWidth >= 750;
                  // Cap map height to ensure it fits better on shorter screens
                  final mapHeight = (isWide
                          ? 560.0
                          : (isTablet ? 420.0 : 300.0))
                      .clamp(150.0, constraints.maxHeight * 0.7);
                  final pagePadding = isWide ? 20.0 : (isTablet ? 16.0 : 10.0);

                  final formSection = _buildFormSection();
                  final mapSection = _buildMapSection(mapHeight);
                  final schoolSection = _buildSchoolSection();
                  final missingGpsSection = _buildMissingGpsSection();

                  if (isWide) {
                    return Padding(
                      padding: EdgeInsets.all(pagePadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: ListView(
                              children: [
                                formSection,
                                const SizedBox(height: 16),
                                schoolSection,
                                const SizedBox(height: 16),
                                missingGpsSection,
                                const SizedBox(height: 16),
                                _buildCreateButton(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(child: mapSection),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.all(pagePadding),
                    children: [
                      formSection,
                      const SizedBox(height: 12),
                      mapSection,
                      const SizedBox(height: 12),
                      schoolSection,
                      const SizedBox(height: 12),
                      missingGpsSection,
                      const SizedBox(height: 12),
                      _buildCreateButton(),
                    ],
                  );
                },
              ),
    );
  }

  Widget _buildFormSection() {
    final hasSelectedAgent =
        _selectedAgentId != null &&
        _agents.any((agent) => agent['id'].toString() == _selectedAgentId);
    final selectedAgentValue = hasSelectedAgent ? _selectedAgentId : null;
    final selectedCountyValue =
        _countyFilters.contains(_selectedCounty)
            ? _selectedCounty
            : 'All Counties';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedAgentValue,
              decoration: const InputDecoration(
                labelText: 'Assign To (Field Agent)',
                border: OutlineInputBorder(),
              ),
              items:
                  _agents.map((agent) {
                    final label =
                        (agent['full_name'] ?? agent['email'] ?? 'Unknown')
                            .toString();
                    return DropdownMenuItem<String>(
                      value: agent['id'].toString(),
                      child: Text(label),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => _selectedAgentId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedCountyValue,
              decoration: const InputDecoration(
                labelText: 'County Filter',
                border: OutlineInputBorder(),
              ),
              items:
                  _countyFilters
                      .map(
                        (county) => DropdownMenuItem<String>(
                          value: county,
                          child: Text(county),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCounty = value);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _selectedDate == null
                    ? 'Pick route date'
                    : 'Route date: ${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(double mapHeight) {
    final routePoints = _selectedRoutePoints();
    final center = _defaultMapCenter();
    final totalVisibleSchools = _visibleSchools.length;
    var geocodedSchools = 0;
    final markers =
        _visibleSchools
            .map((school) {
              final lat = _toDouble(school['latitude']);
              final lng = _toDouble(school['longitude']);
              if (lat == null || lng == null) return null;
              geocodedSchools += 1;
              final isSelected = _selectedSchoolIds.contains(
                school['id'].toString(),
              );
              final stage = _schoolStage(school);
              final baseColor = _stageColor(stage);
              return Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: Tooltip(
                  message:
                      '${(school['name'] ?? 'School').toString()}\n${_stageLabel(stage)}',
                  child: Icon(
                    Icons.location_on,
                    color: baseColor,
                    size: isSelected ? 34 : 28,
                  ),
                ),
              );
            })
            .whereType<Marker>()
            .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route Map',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Pinned: $geocodedSchools / $totalVisibleSchools schools',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._availableStages.map(
                    (stage) => _ColorSwatch(
                      color: _stageColor(stage),
                      label: _stageLabel(stage),
                    ),
                  ),
                  const _ColorSwatch(color: Colors.grey, label: 'No Stage'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: mapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 6.0,
                          minZoom: 3,
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
                          ),
                          if (routePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  color: Colors.orange,
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          if (markers.isNotEmpty) MarkerLayer(markers: markers),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => _Role2RouteFullScreenMapPage(
                                  center: center,
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

  Widget _buildSchoolSection() {
    final visible = _visibleSchools;
    final displayList = visible.take(50).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Schools (${_selectedSchoolIds.length} selected)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (visible.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final s in visible) {
                          final id = s['id'].toString();
                          if (!_selectedSchoolIds.contains(id)) {
                            _selectedSchoolIds.add(id);
                          }
                        }
                      });
                    },
                    child: const Text('Select All'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _schoolSearchController,
              decoration: const InputDecoration(
                hintText: 'Search schools by name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Text('No schools match your filters.')
            else ...[
              ...displayList.map((school) {
                final schoolId = school['id'].toString();
                final isSelected = _selectedSchoolIds.contains(schoolId);
                final sequence = _selectedSchoolIds.indexOf(schoolId) + 1;
                return CheckboxListTile(
                  dense: true,
                  value: isSelected,
                  contentPadding: EdgeInsets.zero,
                  onChanged:
                      (checked) => _toggleSchool(schoolId, checked ?? false),
                  title: Text(
                    (school['name'] ?? 'Unnamed School').toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  isThreeLine: true,
                  secondary:
                      isSelected
                          ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.orange.shade100,
                            child: Text(
                              '$sequence',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          : Icon(
                            Icons.location_on,
                            color: _stageColor(_schoolStage(school)),
                          ),
                  subtitle: Text(
                    '${(school['county'] ?? 'No county').toString()} • ${_stageLabel(_schoolStage(school))}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                );
              }),
              if (visible.length > 50)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Showing first 50 of ${visible.length} schools. Use search to find others.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final bool canCreate =
        _selectedAgentId != null &&
        _selectedAgentId!.isNotEmpty &&
        _selectedDate != null &&
        _selectedSchoolIds.isNotEmpty;

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canCreate ? _createRoutePlan : null,
        icon: const Icon(Icons.route),
        label: const Text('Create Route Plan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildMissingGpsSection() {
    final missing = _visibleSchoolsMissingGps;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Missing GPS Schools (${missing.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (missing.isEmpty)
              const Text('All schools in this filter have valid coordinates.')
            else
              ...missing.take(30).map((school) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.location_off_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text((school['name'] ?? 'Unnamed School').toString()),
                  subtitle: Text((school['county'] ?? 'No county').toString()),
                );
              }),
            if (missing.length > 30)
              Text(
                'Showing first 30 of ${missing.length}.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _Role2RouteFullScreenMapPage extends StatelessWidget {
  const _Role2RouteFullScreenMapPage({
    required this.center,
    required this.routePoints,
    required this.markers,
  });

  final LatLng center;
  final List<LatLng> routePoints;
  final List<Marker> markers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Map - Full Screen')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 6.0,
          minZoom: 3,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          MapTileLayer(
            userAgentPackageName: 'com.longhorn.dehus',
            maxNativeZoom: 19,
          ),
          if (routePoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  color: Colors.orange,
                  strokeWidth: 4,
                ),
              ],
            ),
          if (markers.isNotEmpty) MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}
