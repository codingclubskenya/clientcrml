import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../../services/api_service.dart';

class Role3SupervisionDashboardPage extends StatefulWidget {
  const Role3SupervisionDashboardPage({super.key});

  @override
  State<Role3SupervisionDashboardPage> createState() =>
      _Role3SupervisionDashboardPageState();
}

class _Role3SupervisionDashboardPageState
    extends State<Role3SupervisionDashboardPage> {
  final _api = ApiService();
  final _dbService = DatabaseService();
  bool _isLoading = true;
  String? _selectedCounty;

  final List<String> _counties = const [
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

  List<Map<String, dynamic>> _role5Users = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _geofences = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _breaches = [];
  List<Map<String, dynamic>> _scorecards = [];
  List<Map<String, dynamic>> _notes = [];
  String _scorecardTimeframe = 'Monthly';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _api.currentUserId;
      if (currentUserId == null) return;

      final currentUserRow = await _api.getById('users', currentUserId);
      final supervisorRegion =
          (currentUserRow?['region'] ?? '').toString().trim();

      final usersResponse = await _api.getAll('users', filter: {'role': 5, 'region': supervisorRegion}, limit: 500);
      final users = List<Map<String, dynamic>>.from(usersResponse);
      final userIds = users.map((u) => u['id'].toString()).toList();

      List<Map<String, dynamic>> tasks = [];
      List<Map<String, dynamic>> routes = [];
      List<Map<String, dynamic>> geofences = [];
      List<Map<String, dynamic>> alerts = [];
      List<Map<String, dynamic>> breaches = [];
      List<Map<String, dynamic>> scorecards = [];
      List<Map<String, dynamic>> notes = [];

      if (userIds.isNotEmpty) {
        final tasksResponse = await _api.getAll('tasks', filter: {'assigned_to': {'in': userIds}}, limit: 500);
        tasks = List<Map<String, dynamic>>.from(tasksResponse);

        final routesResponse = await _api.getAll('route_plans', filter: {'assigned_to': {'in': userIds}}, orderBy: 'route_date', orderDir: 'DESC', limit: 500);
        routes = List<Map<String, dynamic>>.from(routesResponse);

        final geofenceResponse = await _api.getAll('geofences', filter: {'assigned_to': {'in': userIds}}, orderBy: 'updated_at', orderDir: 'DESC', limit: 500);
        geofences = List<Map<String, dynamic>>.from(geofenceResponse);

        try {
          final alertResponse = await _api.getAll('supervisor_alerts', filter: {'user_id': {'in': userIds}}, orderBy: 'created_at', orderDir: 'DESC', limit: 500);
          alerts = List<Map<String, dynamic>>.from(alertResponse);
        } catch (_) {}

        try {
          final breachResponse = await _api.getAll('geofence_events', filter: {'event_type': 'breach', 'user_id': {'in': userIds}}, orderBy: 'created_at', orderDir: 'DESC', limit: 500);
          breaches = List<Map<String, dynamic>>.from(breachResponse);
        } catch (_) {}

        try {
          final now = DateTime.now();
          DateTime start;
          if (_scorecardTimeframe == 'Daily') {
            start = DateTime(now.year, now.month, now.day);
          } else if (_scorecardTimeframe == 'Weekly') {
            final temp = now.subtract(Duration(days: now.weekday % 7));
            start = DateTime(temp.year, temp.month, temp.day);
          } else if (_scorecardTimeframe == 'Yearly') {
            start = DateTime(now.year, 1, 1);
          } else {
            start = DateTime(now.year, now.month, 1);
          }
          final startIso = start.toIso8601String();
          final endIso = now.toIso8601String();

          final scorecardsResponse = await _api.getRole5Performance(start: startIso, end: endIso);

          final allScorecards = List<Map<String, dynamic>>.from(
            scorecardsResponse as List,
          );
          scorecards =
              allScorecards
                  .where((s) => userIds.contains(s['user_id']?.toString()))
                  .toList();
        } catch (e) {
          debugPrint('Error fetching scorecards via RPC: $e');
        }

        try {
          final notesResponse = await _api.getAll('supervisor_notes', filter: {'user_id': {'in': userIds}}, orderBy: 'created_at', orderDir: 'DESC', limit: 500);
          notes = List<Map<String, dynamic>>.from(notesResponse);
          final namesById = {for (final user in users) user['id'].toString(): user['full_name']?.toString() ?? user['email']?.toString() ?? 'Unknown'};
          for (final note in notes) {
            note['users'] = {'full_name': namesById[note['user_id']?.toString()] ?? 'Unknown'};
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _role5Users = users;
        _tasks = tasks;
        _routes = routes;
        _geofences = geofences;
        _alerts = alerts;
        _breaches = breaches;
        _scorecards = scorecards;
        _notes = notes;
      });
    } catch (e) {
      debugPrint('Role3 supervision load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load supervision data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _healthForUser(String userId) {
    final now = DateTime.now();
    final overdueCount =
        _tasks.where((t) {
          if (t['assigned_to']?.toString() != userId) return false;
          final status = (t['status'] ?? '').toString().toLowerCase();
          final dueAt = DateTime.tryParse((t['due_at'] ?? '').toString());
          return dueAt != null &&
              dueAt.isBefore(now) &&
              status != 'closed' &&
              status != 'completed';
        }).length;

    final activeAlerts =
        _alerts.where((a) {
          return a['user_id']?.toString() == userId &&
              (a['status'] ?? 'open').toString().toLowerCase() == 'open';
        }).length;

    if (activeAlerts > 0 || overdueCount > 2) return 'Red';
    if (overdueCount > 0) return 'Amber';
    return 'Green';
  }

  Color _healthColor(String health) {
    if (health == 'Red') return Colors.red;
    if (health == 'Amber') return Colors.orange;
    return Colors.green;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_selectedCounty == null || _selectedCounty!.isEmpty) return _role5Users;
    return _role5Users
        .where(
          (u) =>
              (u['region'] ?? '').toString().toLowerCase() ==
              _selectedCounty!.toLowerCase(),
        )
        .toList();
  }

  Future<void> _createIncident(String userId) async {
    await _dbService.insertWithOfflineQueue(
      table: 'supervisor_incidents',
      payload: {
        'user_id': userId,
        'incident_type': 'escalation',
        'severity': 'high',
        'status': 'open',
        'region': _selectedCounty,
        'notes': 'Escalated by supervisor from command center.',
        'created_by': _api.currentUserId,
      },
    );
    await _loadData();
  }

  Future<void> _extendDeadlineForLatestTask(String userId) async {
    final candidate = _tasks
        .where((t) => t['assigned_to']?.toString() == userId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);
    if (candidate == null) return;
    final due = DateTime.tryParse((candidate['due_at'] ?? '').toString());
    if (due == null) return;
    await _api.patch('tasks', candidate['id'].toString(), {'due_at': due.add(const Duration(days: 1)).toIso8601String()});
    await _loadData();
  }

  Future<void> _showAddCoachingNoteDialog(String userId) async {
    final noteController = TextEditingController();
    String contextType = 'general';
    DateTime? followUpDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Coaching Note'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: contextType,
                    decoration: const InputDecoration(
                      labelText: 'Context',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General Review'),
                      ),
                      DropdownMenuItem(
                        value: 'task',
                        child: Text('Task Performance'),
                      ),
                      DropdownMenuItem(
                        value: 'route',
                        child: Text('Route Compliance'),
                      ),
                      DropdownMenuItem(
                        value: 'health_review',
                        child: Text('Health / Risk Review'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => contextType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Follow-up: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 7),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() => followUpDate = picked);
                          }
                        },
                        child: Text(
                          followUpDate == null
                              ? 'Select Date'
                              : '${followUpDate!.year}-${followUpDate!.month}-${followUpDate!.day}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (noteController.text.trim().isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Save Note'),
                ),
              ],
            );
          },
        );
      },
    ).then((saved) async {
      if (saved == true) {
        await _dbService.insertWithOfflineQueue(
          table: 'supervisor_notes',
          payload: {
            'supervisor_id': _api.currentUserId,
            'user_id': userId,
            'region': _selectedCounty,
            'context_type': contextType,
            'note': noteController.text.trim(),
            'follow_up_at': followUpDate?.toIso8601String(),
          },
        );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Coaching note added.')));
        }
      }
    });
  }

  Future<void> _approvePendingRoute(String userId, bool approve) async {
    final pending = _routes.cast<Map<String, dynamic>?>().firstWhere(
      (r) =>
          r?['assigned_to']?.toString() == userId &&
          (r?['status'] ?? '').toString().toLowerCase() == 'submitted',
      orElse: () => null,
    );
    if (pending == null) return;
    await _api.patch('route_plans', pending['id'].toString(), {
          'status': approve ? 'approved' : 'rejected',
          'reviewed_by': _api.currentUserId,
          'reviewed_at': DateTime.now().toIso8601String(),
          'review_note':
              approve
                  ? 'Approved by Role 3 supervisor.'
                  : 'Rejected. Needs correction.',
        });
    await _loadData();
  }

  Future<void> _reassignRoute(String routeId) async {
    final filtered = _filteredUsers;
    if (filtered.isEmpty) return;
    final newAssignee = filtered.first['id']?.toString();
    if (newAssignee == null) return;
    await _api.patch('route_plans', routeId, {'assigned_to': newAssignee});
    await _dbService.insertWithOfflineQueue(
      table: 'audit_events',
      payload: {
        'actor_id': _api.currentUserId,
        'action': 'reassign_route',
        'entity_type': 'route_plans',
        'entity_id': routeId,
        'region': _selectedCounty,
        'after_data': {'assigned_to': newAssignee},
      },
    );
    await _loadData();
  }

  Future<void> _reassignGeofence(String geofenceId) async {
    final filtered = _filteredUsers;
    if (filtered.isEmpty) return;
    final newAssignee = filtered.first['id']?.toString();
    if (newAssignee == null) return;
    await _api.patch('geofences', geofenceId, {'assigned_to': newAssignee, 'region': _selectedCounty});
    await _dbService.insertWithOfflineQueue(
      table: 'audit_events',
      payload: {
        'actor_id': _api.currentUserId,
        'action': 'reassign_geofence',
        'entity_type': 'geofences',
        'entity_id': geofenceId,
        'region': _selectedCounty,
        'after_data': {'assigned_to': newAssignee, 'region': _selectedCounty},
      },
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final filtered = _filteredUsers;
    final filteredIds = filtered.map((u) => u['id'].toString()).toSet();
    final overdueTasks =
        _tasks.where((t) {
          if (!filteredIds.contains(t['assigned_to']?.toString())) return false;
          final dueAt = DateTime.tryParse((t['due_at'] ?? '').toString());
          final status = (t['status'] ?? '').toString().toLowerCase();
          return dueAt != null &&
              dueAt.isBefore(now) &&
              status != 'closed' &&
              status != 'completed';
        }).length;
    final unstartedRoutes =
        _routes.where((r) {
          if (!filteredIds.contains(r['assigned_to']?.toString())) return false;
          return (r['status'] ?? 'assigned').toString().toLowerCase() ==
              'assigned';
        }).length;
    final atRisk =
        filtered
            .where((u) => _healthForUser(u['id'].toString()) != 'Green')
            .length;
    final activeRole5 = filtered.length;
    final openAlerts =
        _alerts.where((a) {
          if (!filteredIds.contains(a['user_id']?.toString())) return false;
          return (a['status'] ?? 'open').toString().toLowerCase() == 'open';
        }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role 3 Supervision Command Center'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCounty,
                      decoration: const InputDecoration(
                        labelText: 'County filter',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All supervised counties'),
                        ),
                        ..._counties.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCounty = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _kpi(
                          'Active Role 5',
                          '$activeRole5',
                          Colors.blue,
                          Icons.groups_2_outlined,
                        ),
                        _kpi(
                          'At Risk Today',
                          '$atRisk',
                          Colors.orange,
                          Icons.warning_amber_outlined,
                        ),
                        _kpi(
                          'Boundary Breaches',
                          '${_breaches.length}',
                          Colors.red,
                          Icons.fmd_bad_outlined,
                        ),
                        _kpi(
                          'Unstarted Routes',
                          '$unstartedRoutes',
                          Colors.purple,
                          Icons.route_outlined,
                        ),
                        _kpi(
                          'Overdue Tasks',
                          '$overdueTasks',
                          Colors.deepOrange,
                          Icons.task_alt_outlined,
                        ),
                        _kpi(
                          'Open Alerts',
                          '$openAlerts',
                          Colors.red.shade700,
                          Icons.notification_important_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionHeader(
                      'Role 5 Health Status',
                      'Green: on-track, Amber: delayed, Red: urgent intervention',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.green,
                            radius: 6,
                          ),
                          label: Text('Green'),
                        ),
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.orange,
                            radius: 6,
                          ),
                          label: Text('Amber'),
                        ),
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: Colors.red,
                            radius: 6,
                          ),
                          label: Text('Red'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...filtered.map((user) {
                      final userId = user['id'].toString();
                      final health = _healthForUser(userId);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 6,
                                    backgroundColor: _healthColor(health),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${user['full_name'] ?? user['email']} (${user['region'] ?? 'Unknown'})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(health),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonal(
                                    onPressed:
                                        () =>
                                            _approvePendingRoute(userId, true),
                                    child: const Text('Approve'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed:
                                        () =>
                                            _approvePendingRoute(userId, false),
                                    child: const Text('Reject'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed:
                                        () => _extendDeadlineForLatestTask(
                                          userId,
                                        ),
                                    child: const Text('Extend'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () => _createIncident(userId),
                                    child: const Text('Incident'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed:
                                        () =>
                                            _showAddCoachingNoteDialog(userId),
                                    child: const Text('Coaching'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    _buildScorecardSection(filteredIds),
                    const SizedBox(height: 24),
                    _buildNotesSection(filteredIds),
                    const SizedBox(height: 24),
                    _sectionHeader(
                      'Route Plans (Role 5)',
                      'Daily execution and reassignment controls',
                    ),
                    const SizedBox(height: 8),
                    ..._routes
                        .where(
                          (r) => filteredIds.contains(
                            r['assigned_to']?.toString(),
                          ),
                        )
                        .map(
                          (route) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.route),
                              title: Text(
                                'Route ${route['route_date']?.toString().split(' ').first ?? 'No date'}',
                              ),
                              subtitle: Text(
                                'Status: ${(route['status'] ?? 'assigned').toString()}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'reassign') {
                                    _reassignRoute(route['id'].toString());
                                  }
                                },
                                itemBuilder:
                                    (context) => const [
                                      PopupMenuItem(
                                        value: 'reassign',
                                        child: Text('Reassign Route'),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    _sectionHeader(
                      'Geofences (Role 5)',
                      'Boundary ownership and county mapping',
                    ),
                    const SizedBox(height: 8),
                    ..._geofences
                        .where(
                          (g) => filteredIds.contains(
                            g['assigned_to']?.toString(),
                          ),
                        )
                        .map(
                          (geo) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.map_outlined),
                              title: Text(
                                geo['name']?.toString() ?? 'Geofence',
                              ),
                              subtitle: Text(
                                'County: ${geo['region'] ?? 'Not set'}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'reassign') {
                                    _reassignGeofence(geo['id'].toString());
                                  }
                                },
                                itemBuilder:
                                    (context) => const [
                                      PopupMenuItem(
                                        value: 'reassign',
                                        child: Text('Reassign Geofence'),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Supervisor SLA Adherence'),
                        subtitle: Text(
                          'Ack < 15 min and resolve < 2 hrs tiles use data from supervisor_alerts.',
                        ),
                        trailing: Text(
                          '${_alerts.where((a) => (a['ack_sla_met'] ?? false) == true).length}'
                          '/${_alerts.length}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildScorecardSection(Set<String> filteredIds) {
    final relevantScorecards =
        _scorecards
            .where((s) => filteredIds.contains(s['user_id']?.toString()))
            .toList();

    relevantScorecards.sort((a, b) {
      final aTasks = (a['total_tasks'] as num?)?.toDouble() ?? 0;
      final aTasksC = (a['completed_tasks'] as num?)?.toDouble() ?? 0;
      final aRoutes = (a['total_routes'] as num?)?.toDouble() ?? 0;
      final aRoutesC = (a['completed_routes'] as num?)?.toDouble() ?? 0;
      final scoreA =
          (aTasks > 0 ? aTasksC / aTasks : 0) +
          (aRoutes > 0 ? aRoutesC / aRoutes : 0);

      final bTasks = (b['total_tasks'] as num?)?.toDouble() ?? 0;
      final bTasksC = (b['completed_tasks'] as num?)?.toDouble() ?? 0;
      final bRoutes = (b['total_routes'] as num?)?.toDouble() ?? 0;
      final bRoutesC = (b['completed_routes'] as num?)?.toDouble() ?? 0;
      final scoreB =
          (bTasks > 0 ? bTasksC / bTasks : 0) +
          (bRoutes > 0 ? bRoutesC / bRoutes : 0);

      return scoreB.compareTo(scoreA); // Descending
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _sectionHeader(
                'Role 5 Performance Scorecard',
                'Ranked by completion metrics',
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _scorecardTimeframe,
                  items:
                      ['Daily', 'Weekly', 'Monthly', 'Yearly']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _scorecardTimeframe = val);
                      _loadData();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (relevantScorecards.isEmpty)
          const Text('No performance data available for this region.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Agent')),
                DataColumn(label: Text('Tasks (Compl/Total)')),
                DataColumn(label: Text('Routes (Compl/Total)')),
                DataColumn(label: Text('Visits Logged')),
              ],
              rows:
                  relevantScorecards.map((s) {
                    final tasksC = s['completed_tasks'] ?? 0;
                    final tasksT = s['total_tasks'] ?? 0;
                    final routesC = s['completed_routes'] ?? 0;
                    final routesT = s['total_routes'] ?? 0;
                    return DataRow(
                      cells: [
                        DataCell(Text(s['full_name']?.toString() ?? 'Unknown')),
                        DataCell(Text('$tasksC / $tasksT')),
                        DataCell(Text('$routesC / $routesT')),
                        DataCell(Text('${s['total_visits'] ?? 0}')),
                      ],
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesSection(Set<String> filteredIds) {
    final relevantNotes =
        _notes
            .where((n) => filteredIds.contains(n['user_id']?.toString()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Coaching Notes', 'Feedback and follow-ups'),
        const SizedBox(height: 8),
        if (relevantNotes.isEmpty)
          const Text('No coaching notes recorded yet.')
        else
          ...relevantNotes.take(5).map((n) {
            final dateRaw = n['created_at']?.toString();
            final dateStr = dateRaw != null ? dateRaw.split('T').first : '';
            final followRaw = n['follow_up_at']?.toString();
            final followStr =
                followRaw != null ? followRaw.split('T').first : 'None';
            final targetName =
                n['users']?['full_name']?.toString() ?? 'Unknown Agent';

            return Card(
              child: ListTile(
                title: Text('$targetName (${n['context_type'] ?? 'general'})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n['note']?.toString() ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      'Follow-up: $followStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          }),
      ],
    );
  }
}
