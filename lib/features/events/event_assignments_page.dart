import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';

class EventAssignmentsPage extends StatefulWidget {
  const EventAssignmentsPage({super.key});

  @override
  State<EventAssignmentsPage> createState() => _EventAssignmentsPageState();
}

class _EventAssignmentsPageState extends State<EventAssignmentsPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _availableAgents = [];
  bool _loading = true;

  String? get _eventId =>
      ModalRoute.of(context)?.settings.arguments is Map
          ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
          : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableAgents() async {
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, email, phone, role')
          .inFilter('role', [4, 5])
          .order('full_name');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error loading agents: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _showAssignDialog() async {
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

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Assign Agent to Event'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Agent:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedAgentId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Choose an agent',
                          ),
                          items:
                              _availableAgents.map((agent) {
                                final name =
                                    agent['full_name']?.toString() ??
                                    agent['email']?.toString() ??
                                    'Unknown';
                                final role =
                                    agent['role'] == 4 ? 'Agent' : 'Sales Rep';
                                return DropdownMenuItem(
                                  value: agent['id']?.toString(),
                                  child: Text('$name ($role)'),
                                );
                              }).toList(),
                          onChanged:
                              (val) =>
                                  setDialogState(() => selectedAgentId = val),
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
                      onPressed:
                          selectedAgentId != null
                              ? () => Navigator.pop(ctx, true)
                              : null,
                      child: const Text('Assign'),
                    ),
                  ],
                ),
          ),
    );

    if (result == true && selectedAgentId != null) {
      await _assignAgent(
        selectedAgentId!,
        scheduleController.text,
        targetController.text,
        notesController.text,
      );
    }
  }

  Future<void> _assignAgent(
    String agentId,
    String schedule,
    String target,
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

      await _dbService.assignAgentToEvent({
        'event_id': eventId,
        'agent_id': agentId,
        'assigned_by': currentUser?.id,
        'schedule': {'notes': schedule},
        'targets': targets,
        'notes': notes,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent assigned successfully')),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assignment failed: $e')));
    }
  }

  Future<void> _removeAssignment(String assignmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove Assignment'),
            content: const Text(
              'Are you sure you want to remove this agent from the event?',
            ),
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
        await _dbService.removeEventAssignment(assignmentId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assignment removed')));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Assignments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _assignments.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _assignments.length,
                itemBuilder: (ctx, i) {
                  final a = _assignments[i];
                  final user = a['users'] as Map<String, dynamic>?;
                  final name =
                      user?['full_name']?.toString() ??
                      user?['email']?.toString() ??
                      'Unknown Agent';
                  final phone = user?['phone']?.toString() ?? '';
                  final targets = a['targets'] as Map<String, dynamic>? ?? {};
                  final schedule = a['schedule'] as Map<String, dynamic>? ?? {};

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (phone.isNotEmpty) Text('Phone: $phone'),
                          if (schedule['notes'] != null)
                            Text(
                              'Schedule: ${schedule['notes']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (targets['sales_target'] != null)
                            Text(
                              'Target: KES ${targets['sales_target']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle,
                          color: Colors.red,
                        ),
                        onPressed:
                            () => _removeAssignment(a['id']?.toString() ?? ''),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Assign Agent'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No agents assigned yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAssignDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Assign Agent'),
          ),
        ],
      ),
    );
  }
}
