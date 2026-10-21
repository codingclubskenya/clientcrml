import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../services/api_service.dart';

class RoutePlansManagementPage extends StatefulWidget {
  const RoutePlansManagementPage({super.key});

  @override
  State<RoutePlansManagementPage> createState() =>
      _RoutePlansManagementPageState();
}

class _RoutePlansManagementPageState extends State<RoutePlansManagementPage> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  DateTime _selectedDate = DateTime.now();
  String? _selectedAssignee;
  String _selectedStatus = 'draft';
  Map<String, dynamic>? _editingPlan;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _agents = [];
  Map<String, String> _agentNames = {};

  static const _statuses = [
    'draft',
    'assigned',
    'submitted',
    'approved',
    'rejected',
    'in_progress',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final userId = ApiService().currentUserId;
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _plans = [];
          _agents = [];
          _agentNames = {};
        });
        return;
      }
      final results = await Future.wait([
        ApiService().getAll(
          'route_plans', filter: {'created_by': userId},
          orderBy: 'route_date', orderDir: 'DESC', limit: 500,
        ),
        ApiService().getAll(
          'users', filter: {'role': {'in': [4, 5]}},
          orderBy: 'full_name', orderDir: 'ASC', limit: 500,
        ),
      ]);
      final agents = List<Map<String, dynamic>>.from(results[1]);
      if (!mounted) return;
      setState(() {
        _plans = List<Map<String, dynamic>>.from(results[0]);
        _agents = agents;
        _agentNames = {
          for (final agent in agents)
            agent['id'].toString():
                (agent['full_name'] ?? agent['email'] ?? 'Agent').toString(),
        };
      });
    } catch (e) {
      _showMessage('Failed to load route plans: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _parseDate(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

  String _assigneeName(dynamic id) =>
      id == null
          ? 'Unassigned'
          : (_agentNames[id.toString()] ?? 'Assigned user');

  int _stopCount(Map<String, dynamic> plan) =>
      plan['school_ids'] is List ? (plan['school_ids'] as List).length : 0;

  Future<void> _openEditor([Map<String, dynamic>? plan]) async {
    _editingPlan = plan;
    _titleController.text = plan?['title']?.toString() ?? '';
    _notesController.text = plan?['notes']?.toString() ?? '';
    _selectedDate = _parseDate(plan?['route_date']);
    final planAssignee = plan?['assigned_to']?.toString();
    _selectedAssignee =
        planAssignee != null &&
                _agents.any((agent) => agent['id'].toString() == planAssignee)
            ? planAssignee
            : null;
    _selectedStatus = plan?['status']?.toString() ?? 'draft';
    if (!_statuses.contains(_selectedStatus)) _selectedStatus = 'draft';

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  title: Text(
                    plan == null ? 'Create Route Plan' : 'Edit Route Plan',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title'),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Route date: ${_dateString(_selectedDate)}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: dialogContext,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (date != null)
                              setDialogState(() => _selectedDate = date);
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: _selectedAssignee ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Assign to',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Unassigned (assign later)'),
                            ),
                            ..._agents.map(
                              (agent) => DropdownMenuItem<String>(
                                value: agent['id'].toString(),
                                child: Text(_assigneeName(agent['id'])),
                              ),
                            ),
                          ],
                          onChanged:
                              (value) => setDialogState(
                                () =>
                                    _selectedAssignee =
                                        value == null || value.isEmpty
                                            ? null
                                            : value,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items:
                              _statuses
                                  .map(
                                    (status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (value) => setDialogState(
                                () =>
                                    _selectedStatus = value ?? _selectedStatus,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          _saving
                              ? null
                              : () async {
                                final saved = await _savePlan();
                                if (saved && mounted)
                                  Navigator.pop(dialogContext);
                              },
                      child: Text(plan == null ? 'Create' : 'Save'),
                    ),
                  ],
                ),
          ),
    );
    _editingPlan = null;
  }

  Future<bool> _savePlan() async {
    final userId = ApiService().currentUserId;
    if (userId == null) return false;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Enter a route plan title.', error: true);
      return false;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'route_date': _dateString(_selectedDate),
        'assigned_to': _selectedAssignee,
        'notes': _notesController.text.trim(),
        'status': _selectedAssignee == null ? 'draft' : _selectedStatus,
      };
      if (_editingPlan == null) {
        payload['school_ids'] = <String>[];
        payload['created_by'] = userId;
        await ApiService().create('route_plans', payload);
      } else {
        if (_editingPlan!['created_by']?.toString() != userId) {
          throw StateError('You can only update route plans you created.');
        }
        await ApiService().patch(
          'route_plans', _editingPlan!['id'].toString(), payload,
        );
      }
      await _load();
      _showMessage(
        _editingPlan == null ? 'Route plan created.' : 'Route plan updated.',
      );
      return true;
    } catch (e) {
      _showMessage('Failed to save route plan: $e', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _assignPlan(Map<String, dynamic> plan) async {
    final planAssignee = plan['assigned_to']?.toString();
    String? assignee =
        planAssignee != null &&
                _agents.any((agent) => agent['id'].toString() == planAssignee)
            ? planAssignee
            : null;
    final selected = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, setDialogState) => AlertDialog(
                  title: const Text('Assign Route Plan'),
                  content: DropdownButtonFormField<String>(
                    value: assignee ?? '',
                    decoration: const InputDecoration(labelText: 'Field agent'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Select a field agent'),
                      ),
                      ..._agents.map(
                        (agent) => DropdownMenuItem<String>(
                          value: agent['id'].toString(),
                          child: Text(_assigneeName(agent['id'])),
                        ),
                      ),
                    ],
                    onChanged:
                        (value) => setDialogState(() => assignee = value),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, assignee),
                      child: const Text('Assign'),
                    ),
                  ],
                ),
          ),
    );
    if (selected == null || selected.isEmpty) return;
    try {
      final userId = ApiService().currentUserId;
      if (userId == null || plan['created_by']?.toString() != userId) {
        throw StateError('You can only assign route plans you created.');
      }
      await ApiService().patch('route_plans', plan['id'].toString(), {
        'assigned_to': selected, 'status': 'assigned',
      });
      await _load();
      _showMessage('Route plan assigned.');
    } catch (e) {
      _showMessage('Failed to assign route plan: $e', error: true);
    }
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete route plan?'),
            content: Text('Delete “${plan['title'] ?? 'Route Plan'}”?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      final userId = ApiService().currentUserId;
      if (userId == null || plan['created_by']?.toString() != userId) {
        throw StateError('You can only delete route plans you created.');
      }
      await ApiService().delete('route_plans', plan['id'].toString());
      await _load();
      _showMessage('Route plan deleted.');
    } catch (e) {
      _showMessage('Failed to delete route plan: $e', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Route Plans'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Create Route Plan'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child:
                    _plans.isEmpty
                        ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('No route plans created yet.')),
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                          itemCount: _plans.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final plan = _plans[index];
                            final assigned = plan['assigned_to'] != null;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.route,
                                          color: AppColors.primaryGreen,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            plan['title']?.toString() ??
                                                'Route Plan',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (action) {
                                            if (action == 'edit')
                                              _openEditor(plan);
                                            if (action == 'delete')
                                              _deletePlan(plan);
                                          },
                                          itemBuilder:
                                              (_) => const [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('Edit'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete'),
                                                ),
                                              ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${plan['route_date'] ?? ''}  •  ${plan['status'] ?? 'draft'}  •  ${_stopCount(plan)} stops',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Assigned to: ${_assigneeName(plan['assigned_to'])}',
                                    ),
                                    if (!assigned) ...[
                                      const SizedBox(height: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => _assignPlan(plan),
                                        icon: const Icon(Icons.person_add),
                                        label: const Text('Assign route plan'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
    );
  }
}
