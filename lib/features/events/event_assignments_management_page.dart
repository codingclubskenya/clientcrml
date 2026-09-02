import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventAssignmentsManagementPage extends StatefulWidget {
  const EventAssignmentsManagementPage({super.key});

  @override
  State<EventAssignmentsManagementPage> createState() => _EventAssignmentsManagementPageState();
}

class _EventAssignmentsManagementPageState extends State<EventAssignmentsManagementPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _availableAgents = [];
  bool _loading = true;
  bool _canManage = false;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map
      ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRoleAndLoad());
  }

  Future<void> _checkRoleAndLoad() async {
    try {
      final role = await _dbService.getCurrentUserRole();
      if (role == 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You do not have permission to manage assignments')),
          );
          Navigator.pop(context);
        }
        return;
      }
      if (mounted) {
        setState(() => _canManage = true);
        _load();
      }
    } catch (e) {
      debugPrint('Error checking role: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final assignments = await _dbService.getEventAssignments(id);
      final agents = await _getAvailableAgents();
      setState(() {
        _assignments = assignments;
        _availableAgents = agents;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableAgents() async {
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, email, phone, role, region')
          .inFilter('role', [4, 5])
          .order('full_name');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading agents: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _showAddAssignmentDialog() async {
    if (_availableAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No agents available to assign')),
      );
      return;
    }

    String? selectedAgentId;
    final scheduleController = TextEditingController();
    final notesController = TextEditingController();
    final targetController = TextEditingController();
    final productController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Agent to Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Agent:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedAgentId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Choose an agent',
                  ),
                  items: _availableAgents.map((agent) {
                    final name = agent['full_name']?.toString() ?? agent['email']?.toString() ?? 'Unknown';
                    final role = agent['role'] == 4 ? 'Agent' : 'Sales Rep';
                    final region = agent['region']?.toString() ?? '';
                    return DropdownMenuItem(
                      value: agent['id']?.toString(),
                      child: Text('$name ($role) - $region'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedAgentId = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: scheduleController,
                  decoration: const InputDecoration(
                    labelText: 'Schedule Notes',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Morning shift 9am-1pm',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Sales Target (KES)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: productController,
                  decoration: const InputDecoration(
                    labelText: 'Products to Promote',
                    border: OutlineInputBorder(),
                    hintText: 'Comma-separated list',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedAgentId != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedAgentId != null) {
      await _addAssignment(
        selectedAgentId!,
        scheduleController.text,
        targetController.text,
        productController.text,
        notesController.text,
      );
    }
  }

  Future<void> _addAssignment(
    String agentId,
    String schedule,
    String target,
    String products,
    String notes,
  ) async {
    final eventId = _eventId;
    if (eventId == null) return;

    try {
      final currentUser = _supabase.auth.currentUser;
      final targets = <String, dynamic>{};
      if (target.isNotEmpty) {
        targets['sales_target'] = double.tryParse(target) ?? 0;
      }

      final productList = products.isNotEmpty
          ? products.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      await _dbService.assignAgentToEvent({
        'event_id': eventId,
        'agent_id': agentId,
        'assigned_by': currentUser?.id,
        'schedule': {'notes': schedule},
        'targets': targets,
        'products': productList,
        'notes': notes,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent assigned successfully')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Assignment failed: $e')),
        );
      }
    }
  }

  Future<void> _editAssignment(Map<String, dynamic> assignment) async {
    final user = assignment['users'] as Map<String, dynamic>?;
    final name = user?['full_name']?.toString() ?? user?['email']?.toString() ?? 'Unknown';

    final scheduleController = TextEditingController(
      text: (assignment['schedule'] as Map<String, dynamic>?)?['notes']?.toString() ?? '',
    );
    final notesController = TextEditingController(text: assignment['notes']?.toString() ?? '');
    final targetController = TextEditingController(
      text: (assignment['targets'] as Map<String, dynamic>?)?['sales_target']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Assignment - $name'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: scheduleController,
                decoration: const InputDecoration(
                  labelText: 'Schedule Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                decoration: const InputDecoration(
                  labelText: 'Sales Target (KES)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final targets = <String, dynamic>{};
        if (targetController.text.isNotEmpty) {
          targets['sales_target'] = double.tryParse(targetController.text) ?? 0;
        }

        await _supabase.from('event_assignments').update({
          'schedule': {'notes': scheduleController.text.trim()},
          'targets': targets,
          'notes': notesController.text.trim(),
        }).eq('id', assignment['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment updated')),
          );
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeAssignment(Map<String, dynamic> assignment) async {
    final user = assignment['users'] as Map<String, dynamic>?;
    final name = user?['full_name']?.toString() ?? user?['email']?.toString() ?? 'Unknown';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Assignment'),
        content: Text('Remove $name from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.removeEventAssignment(assignment['id']?.toString() ?? '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment removed')),
          );
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Assignments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Colors.blue.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_assignments.length} Agent(s) Assigned',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddAssignmentDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Agent'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_assignments.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No agents assigned yet'),
                          SizedBox(height: 8),
                          Text('Tap "Add Agent" to assign agents to this event', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ..._assignments.map((a) {
                    final user = a['users'] as Map<String, dynamic>?;
                    final name = user?['full_name']?.toString() ?? user?['email']?.toString() ?? 'Unknown Agent';
                    final phone = user?['phone']?.toString() ?? '';
                    final email = user?['email']?.toString() ?? '';
                    final role = user?['role'] == 4 ? 'Agent' : 'Sales Rep';
                    final targets = a['targets'] as Map<String, dynamic>? ?? {};
                    final schedule = a['schedule'] as Map<String, dynamic>? ?? {};
                    final products = a['products'] as List<dynamic>? ?? [];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _editAssignment(a);
                                    if (value == 'remove') _removeAssignment(a);
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(),
                            if (email.isNotEmpty) _buildInfoRow(Icons.email, email),
                            if (phone.isNotEmpty) _buildInfoRow(Icons.phone, phone),
                            if (schedule['notes'] != null)
                              _buildInfoRow(Icons.schedule, schedule['notes'].toString()),
                            if (targets['sales_target'] != null)
                              _buildInfoRow(Icons.track_changes, 'Target: KES ${targets['sales_target']}'),
                            if (a['notes'] != null && a['notes'].toString().isNotEmpty)
                              _buildInfoRow(Icons.note, a['notes'].toString()),
                            if (products.isNotEmpty)
                              _buildInfoRow(Icons.inventory, 'Products: ${products.join(', ')}'),
                            if (a['created_at'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Assigned: ${EventDateFormat.format(a['created_at'])}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssignmentDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Agent'),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
        ],
      ),
    );
  }
}
