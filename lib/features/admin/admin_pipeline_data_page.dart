import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../profile/crm_notification_service.dart';
import '../../services/api_service.dart';

class AdminPipelineDataPage extends StatefulWidget {
  const AdminPipelineDataPage({super.key});

  @override
  State<AdminPipelineDataPage> createState() => _AdminPipelineDataPageState();
}

class _AdminPipelineDataPageState extends State<AdminPipelineDataPage> {
  final _dbService = DatabaseService();
  bool _loading = true;
  String _stageFilter = 'all';
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _schoolNamesById = {};
  Map<String, String> _userNamesById = {};
  List<Map<String, dynamic>> _owners = [];

  static const List<String> _stages = [
    'all',
    'lead',
    'contacted',
    'meeting_scheduled',
    'sample_issued',
    'quotation_sent',
    'decision_pending',
    'negotiation',
    'won',
    'lost',
    'dormant',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _normalizeStage(dynamic value) {
    return (value?.toString() ?? '').trim().toLowerCase();
  }

  String _stageLabel(String stage) {
    return stage.replaceAll('_', ' ').toUpperCase();
  }

  Color _stageColor(String stage) {
    switch (_normalizeStage(stage)) {
      case 'won':
        return Colors.green;
      case 'lost':
      case 'dormant':
        return Colors.redAccent;
      case 'negotiation':
      case 'decision_pending':
      case 'quotation_sent':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      Future<List<Map<String, dynamic>>> runSalesQuery(
        String selectClause,
      ) async {
        final res = await ApiService().getAll(
          'school_sales',
          filter: _stageFilter == 'all'
              ? null
              : {'sale_status': _stageFilter.trim().toLowerCase()},
          orderBy: 'updated_at', orderDir: 'DESC', limit: 500,
        );
        var rows = List<Map<String, dynamic>>.from(res);
        if (_stageFilter != 'all') {
          final wanted = _stageFilter.trim().toLowerCase();
          rows =
              rows
                  .where((row) => _normalizeStage(row['sale_status']) == wanted)
                  .toList();
        }
        return rows;
      }

      List<Map<String, dynamic>> rows;
      try {
        rows = await runSalesQuery('''
          id,
          school_id,
          agent_id,
          package_name,
          expected_value,
          notes,
          sale_status,
          probability,
          expected_close_date,
          stage_contact_person,
          sample_quantity,
          quotation_reference,
          decision_owner,
          negotiation_topic,
          loss_reason,
          dormant_reason,
          stage_updated_at,
          created_at
        ''');
      } catch (_) {
        rows = await runSalesQuery('''
          id,
          school_id,
          agent_id,
          package_name,
          expected_value,
          notes,
          sale_status,
          probability,
          expected_close_date,
          created_at
        ''');
      }

      final schoolIds =
          rows
              .map((r) => r['school_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
      final userIds =
          rows
              .map((r) => r['agent_id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();

      final schoolNamesById = <String, String>{};
      if (schoolIds.isNotEmpty) {
        try {
          final schoolRows = await ApiService().getAll('schools', filter: {
            'id': {'in': schoolIds},
          }, limit: 500);
          for (final map in schoolRows) {
            schoolNamesById[map['id'].toString()] =
                map['name']?.toString() ?? '-';
          }
        } catch (_) {}
      }

      final userNamesById = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final userRows = await ApiService().getAll('users', filter: {
            'id': {'in': userIds},
          }, limit: 500);
          for (final map in userRows) {
            userNamesById[map['id'].toString()] =
                map['full_name']?.toString() ?? map['email']?.toString() ?? '-';
          }
        } catch (_) {}
      }

      final ownersRes = await ApiService().getAll('users',
        filter: {'role': {'in': [2, 3, 4, 5]}},
        orderBy: 'full_name', orderDir: 'ASC', limit: 500,
      );
      final owners = List<Map<String, dynamic>>.from(ownersRes);

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _schoolNamesById = schoolNamesById;
        _userNamesById = userNamesById;
        _owners = owners;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await CrmNotificationService.showIfEnabled(
        context,
        message: 'Failed to load pipeline data. Details: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _updateStage(Map<String, dynamic> row) async {
    String selected = _normalizeStage(row['sale_status']);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Stage'),
          content: StatefulBuilder(
            builder: (_, setDialog) {
              return DropdownButtonFormField<String>(
                initialValue: selected,
                items:
                    _stages
                        .where((s) => s != 'all')
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(_stageLabel(s)),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialog(() => selected = value);
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (updated == null) return;

    await ApiService().patch('school_sales', row['id'].toString(), {
          'sale_status': updated,
          'probability': _probabilityForStage(updated),
          'stage_updated_at': DateTime.now().toIso8601String(),
          'closed_at':
              updated == 'won' ? DateTime.now().toIso8601String() : null,
        });
    await _load();
  }

  int _probabilityForStage(String stage) {
    switch (stage) {
      case 'lead':
        return 10;
      case 'contacted':
        return 20;
      case 'meeting_scheduled':
        return 35;
      case 'sample_issued':
        return 50;
      case 'quotation_sent':
        return 65;
      case 'decision_pending':
        return 75;
      case 'negotiation':
        return 85;
      case 'won':
        return 100;
      default:
        return 0;
    }
  }

  Future<void> _assignOwner(Map<String, dynamic> row) async {
    String? selected = row['agent_id']?.toString();
    final updated = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign Owner'),
          content: StatefulBuilder(
            builder: (_, setDialog) {
              return DropdownButtonFormField<String>(
                initialValue: selected,
                items:
                    _owners
                        .map(
                          (o) => DropdownMenuItem(
                            value: o['id']?.toString(),
                            child: Text(
                              '${o['full_name'] ?? o['email']} (Role ${o['role']})',
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setDialog(() => selected = value),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  selected == null
                      ? null
                      : () => Navigator.pop(context, selected),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
    if (updated == null) return;
    await ApiService().patch('school_sales', row['id'].toString(), {
      'agent_id': updated,
    });
    await _load();
  }

  Future<void> _addFollowUp(Map<String, dynamic> row) async {
    final nextStepController = TextEditingController();
    DateTime? dueDate = DateTime.now().add(const Duration(days: 2));

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Follow-up'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nextStepController,
                    decoration: const InputDecoration(labelText: 'Next Action'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked == null) return;
                      setDialogState(() => dueDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      dueDate == null
                          ? 'Pick Due Date'
                          : 'Due: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;
    if ((row['school_id']?.toString().isEmpty ?? true) ||
        nextStepController.text.trim().isEmpty ||
        dueDate == null) {
      return;
    }

    await _dbService.insertWithOfflineQueue(
      table: 'school_follow_ups',
      payload: {
        'school_id': row['school_id'],
        'agent_id': row['agent_id'],
        'next_step': nextStepController.text.trim(),
        'due_at': dueDate!.toIso8601String(),
        'notes': 'Added by admin from pipeline view',
        'follow_up_status': 'open',
      },
    );
  }

  Future<void> _viewTimeline(Map<String, dynamic> row) async {
    final schoolId = row['school_id']?.toString();
    if (schoolId == null || schoolId.isEmpty) return;

    final followUps = await ApiService().getAll(
      'school_follow_ups', filter: {'school_id': schoolId},
      orderBy: 'created_at', orderDir: 'DESC', limit: 20,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final timelineItems = List<Map<String, dynamic>>.from(
          followUps.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Timeline • ${_schoolNamesById[schoolId] ?? 'School'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Stage: ${_stageLabel(_normalizeStage(row['sale_status']))}',
                    ),
                    subtitle: Text(
                      'Updated: ${row['stage_updated_at'] ?? row['created_at'] ?? '-'}',
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'Follow-ups',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        timelineItems.isEmpty
                            ? const Center(child: Text('No follow-up items.'))
                            : ListView.builder(
                              itemCount: timelineItems.length,
                              itemBuilder: (_, i) {
                                final f = timelineItems[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.event_note_outlined,
                                  ),
                                  title: Text(
                                    f['next_step']?.toString() ?? '-',
                                  ),
                                  subtitle: Text(
                                    'Due: ${f['due_at'] ?? '-'} • ${f['follow_up_status'] ?? '-'}',
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline Data'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Text('Stage Filter:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _stageFilter,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items:
                          _stages
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s == 'all' ? 'All' : _stageLabel(s),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _stageFilter = value);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                      ? const Center(child: Text('No pipeline data found.'))
                      : ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          final stage = _normalizeStage(row['sale_status']);
                          final school =
                              _schoolNamesById[row['school_id']?.toString()] ??
                              'Unknown School';
                          final owner =
                              _userNamesById[row['agent_id']?.toString()] ??
                              'Unassigned';

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              school,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              row['package_name']?.toString() ??
                                                  '-',
                                              style: const TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _stageColor(
                                            stage,
                                          ).withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _stageLabel(stage),
                                          style: TextStyle(
                                            color: _stageColor(stage),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    children: [
                                      Text('Owner: $owner'),
                                      Text(
                                        'Value: KES ${(row['expected_value'] ?? 0).toString()}',
                                      ),
                                      Text(
                                        'Probability: ${(row['probability'] ?? 0)}%',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _actionButton(
                                        icon: Icons.alt_route,
                                        label: 'Edit Stage',
                                        onTap: () => _updateStage(row),
                                      ),
                                      _actionButton(
                                        icon: Icons.person_outline,
                                        label: 'Assign Owner',
                                        onTap: () => _assignOwner(row),
                                      ),
                                      _actionButton(
                                        icon: Icons.add_task,
                                        label: 'Add Follow-up',
                                        onTap: () => _addFollowUp(row),
                                      ),
                                      _actionButton(
                                        icon: Icons.history,
                                        label: 'View Timeline',
                                        onTap: () => _viewTimeline(row),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
