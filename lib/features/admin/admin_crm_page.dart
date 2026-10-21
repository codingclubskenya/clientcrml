import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../profile/crm_notification_service.dart';
import '../../core/constants/colors.dart';
import 'school_profile_page.dart';
import 'duplicate_detection_page.dart';
import 'audit_log_page.dart';
import '../../services/api_service.dart';

class AdminCrmPage extends StatefulWidget {
  const AdminCrmPage({super.key});

  @override
  State<AdminCrmPage> createState() => _AdminCrmPageState();
}

class _AdminCrmPageState extends State<AdminCrmPage> {
  final _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<_CrmRecord> _records = <_CrmRecord>[];
  final Map<String, Map<String, dynamic>> _schoolsById = {};
  final Map<String, Map<String, dynamic>> _usersById = {};
  Map<String, dynamic> _dailyPerformance = {};
  Map<String, dynamic> _weeklyPerformance = {};
  Map<String, dynamic> _monthlyPerformance = {};
  Map<String, dynamic> _yearlyPerformance = {};
  bool _isLoading = true;

  final List<String> _stages = <String>[
    'All',
    'Lead',
    'Qualified',
    'Proposal',
    'Negotiation',
    'Won',
    'Lost',
  ];

  String _selectedStage = 'All';
  bool _sortAscending = false;
  bool _isKanbanView = true;

  @override
  void initState() {
    super.initState();
    _loadCrmData();
  }

  Future<void> _loadCrmData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService().getAll('schools', limit: 500),
        ApiService().getAll('users', limit: 500),
        ApiService().getAll('school_sales', orderBy: 'updated_at',
          orderDir: 'DESC', limit: 500),
      ]);
      final schoolsRes = results[0];
      final usersRes = results[1];
      final salesRes = results[2];

      try {
        _dailyPerformance = await _dbService.getPerformanceMetrics(
          period: 'daily',
          role: 1,
        );
        _weeklyPerformance = await _dbService.getPerformanceMetrics(
          period: 'weekly',
          role: 1,
        );
        _monthlyPerformance = await _dbService.getPerformanceMetrics(
          period: 'monthly',
          role: 1,
        );
        _yearlyPerformance = await _dbService.getPerformanceMetrics(
          period: 'yearly',
          role: 1,
        );
      } catch (_) {}

      _schoolsById
        ..clear()
        ..addEntries(
          List<Map<String, dynamic>>.from(
            schoolsRes,
          ).map((s) => MapEntry(s['id'].toString(), s)),
        );
      _usersById
        ..clear()
        ..addEntries(
          List<Map<String, dynamic>>.from(
            usersRes,
          ).map((u) => MapEntry(u['id'].toString(), u)),
        );

      _records
        ..clear()
        ..addAll(
          List<Map<String, dynamic>>.from(salesRes).map((row) {
            final school = _schoolsById[row['school_id']?.toString()] ?? {};
            final owner = _usersById[row['agent_id']?.toString()] ?? {};
            final stageDb = (row['sale_status'] ?? 'lead').toString();
            final stage = _fromDbStage(stageDb);
            return _CrmRecord(
              id: row['id'].toString(),
              schoolId: row['school_id']?.toString() ?? '',
              ownerId: row['agent_id']?.toString(),
              school: (school['name'] ?? 'Unknown School').toString(),
              contact: 'N/A',
              phone: (school['phone'] ?? '').toString(),
              stage: stage,
              owner:
                  (owner['full_name'] ?? owner['email'] ?? 'Unassigned')
                      .toString(),
              dealValue: ((row['expected_value'] ?? 0) as num).toDouble(),
              lastContact:
                  DateTime.tryParse(
                    (row['stage_updated_at'] ?? row['created_at'] ?? '')
                        .toString(),
                  ) ??
                  DateTime.now(),
              nextActionDate:
                  DateTime.tryParse(
                    (row['next_action_date'] ?? '').toString(),
                  ) ??
                  DateTime.now().add(const Duration(days: 2)),
              probability: (row['probability'] as num?)?.toInt() ?? 0,
              notes: (row['notes'] ?? '').toString(),
              leadScore: (school['lead_score'] as num?)?.toInt() ?? 0,
              latitude: (school['latitude'] as num?)?.toDouble(),
              longitude: (school['longitude'] as num?)?.toDouble(),
            );
          }),
        );
    } catch (e) {
      if (mounted) {
        await CrmNotificationService.showIfEnabled(
          context,
          message: 'Failed to load CRM data: $e',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _schoolController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _ownerController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<_CrmRecord> get _visibleRecords {
    final query = _searchController.text.trim().toLowerCase();
    final rows =
        _records.where((record) {
          final stageMatch =
              _selectedStage == 'All' || record.stage == _selectedStage;
          final textMatch =
              query.isEmpty ||
              record.school.toLowerCase().contains(query) ||
              record.contact.toLowerCase().contains(query) ||
              record.owner.toLowerCase().contains(query) ||
              record.notes.toLowerCase().contains(query);
          return stageMatch && textMatch;
        }).toList();
    rows.sort(
      (a, b) =>
          _sortAscending
              ? a.lastContact.compareTo(b.lastContact)
              : b.lastContact.compareTo(a.lastContact),
    );
    return rows;
  }

  double get _pipelineValue => _visibleRecords
      .where((record) => record.stage == 'Won')
      .fold(0, (sum, record) => sum + record.dealValue);
  int get _atRiskCount =>
      _visibleRecords.where((record) => record.riskLevel == 'High').length;

  int _countByStage(String stage) =>
      _visibleRecords.where((r) => r.stage == stage).length;

  String _formatDealValue(_CrmRecord record) {
    final amount = record.dealValue.toStringAsFixed(0);
    return record.stage == 'Won' ? 'KES $amount' : amount;
  }

  Future<void> _openAddDialog() async {
    _schoolController.clear();
    _contactController.clear();
    _phoneController.clear();
    _ownerController.clear();
    _valueController.clear();
    _notesController.clear();
    String selectedStage = 'Lead';

    final created = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Add CRM Record'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_schoolController, 'School'),
                        _field(_contactController, 'Contact Person'),
                        _field(_phoneController, 'Phone'),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStage,
                          items:
                              _stages
                                  .where((stage) => stage != 'All')
                                  .map(
                                    (stage) => DropdownMenuItem(
                                      value: stage,
                                      child: Text(stage),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedStage = value);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _field(_ownerController, 'Owner'),
                        _field(
                          _valueController,
                          'Deal Value',
                          inputType: TextInputType.number,
                        ),
                        _field(_notesController, 'Notes', maxLines: 2),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final parsed = double.tryParse(_valueController.text);
                        if (_schoolController.text.trim().isEmpty ||
                            _contactController.text.trim().isEmpty ||
                            _ownerController.text.trim().isEmpty ||
                            parsed == null) {
                          return;
                        }
                        final schoolEntry = _schoolsById.values.firstWhere(
                          (s) =>
                              (s['name'] ?? '').toString().toLowerCase() ==
                              _schoolController.text.trim().toLowerCase(),
                          orElse: () => const {},
                        );
                        if (schoolEntry.isEmpty) return;
                        final ownerEntry = _usersById.values.firstWhere(
                          (u) =>
                              (u['full_name'] ?? u['email'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              _ownerController.text.trim().toLowerCase(),
                          orElse: () => const {},
                        );
                        _dbService
                            .insertWithOfflineQueue(
                              table: 'school_sales',
                              payload: {
                                'school_id': schoolEntry['id'],
                                'agent_id': ownerEntry['id'],
                                'package_name': 'CRM Opportunity',
                                'expected_value': parsed,
                                'notes': _notesController.text.trim(),
                                'sale_status': _toDbStage(selectedStage),
                                'probability': _probabilityByStage(
                                  selectedStage,
                                ),
                                'next_action': 'Follow up call',
                                'next_action_date':
                                    DateTime.now()
                                        .add(const Duration(days: 2))
                                        .toIso8601String(),
                              },
                            )
                            .then((_) {
                              if (mounted) {
                                // ignore: use_build_context_synchronously
                                Navigator.pop(context, true);
                                _loadCrmData();
                              }
                            });
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );

    if (created == true && mounted) {
      await CrmNotificationService.showIfEnabled(
        context,
        message: 'CRM record added',
      );
    }
  }

  Future<void> _openEditDialog(_CrmRecord record) async {
    _schoolController.text = record.school;
    _contactController.text = record.contact;
    _phoneController.text = record.phone;
    _ownerController.text = record.owner;
    _valueController.text = record.dealValue.toStringAsFixed(0);
    _notesController.text = record.notes;
    String selectedStage = record.stage;

    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Edit CRM Record'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(_schoolController, 'School'),
                        _field(_contactController, 'Contact Person'),
                        _field(_phoneController, 'Phone'),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStage,
                          items:
                              _stages
                                  .where((stage) => stage != 'All')
                                  .map(
                                    (stage) => DropdownMenuItem(
                                      value: stage,
                                      child: Text(stage),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedStage = value);
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Stage',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _field(_ownerController, 'Owner'),
                        _field(
                          _valueController,
                          'Deal Value',
                          inputType: TextInputType.number,
                        ),
                        _field(_notesController, 'Notes', maxLines: 2),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final parsed = double.tryParse(_valueController.text);
                        if (parsed == null) return;
                        ApiService().patch('school_sales', record.id, {
                              'expected_value': parsed,
                              'notes': _notesController.text.trim(),
                              'sale_status': _toDbStage(selectedStage),
                              'probability': _probabilityByStage(selectedStage),
                              'stage_updated_at':
                                  DateTime.now().toIso8601String(),
                              'next_action': 'Follow up call',
                              'next_action_date':
                                  DateTime.now()
                                      .add(const Duration(days: 2))
                                      .toIso8601String(),
                            }).then((_) async {
                              if (mounted) {
                                Navigator.pop(context);
                                await _loadCrmData();
                              }
                            });
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;
    final isSmallScreen = MediaQuery.of(context).size.width < 720;
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.longhornMaroon,
        foregroundColor: Colors.white,
        title: const Text(
          'CRM Workspace',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isDesktop) ...[
            Theme(
              data: Theme.of(context).copyWith(
                toggleButtonsTheme: const ToggleButtonsThemeData(
                  selectedColor: Colors.white,
                  fillColor: Colors.white24,
                  color: Colors.white70,
                ),
              ),
              child: ToggleButtons(
                isSelected: [!_isKanbanView, _isKanbanView],
                onPressed: (index) {
                  setState(() => _isKanbanView = index == 1);
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 48),
                children: const [
                  Icon(Icons.table_rows, size: 20),
                  Icon(Icons.view_kanban, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Duplicate Detection',
              color: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DuplicateDetectionPage(),
                  ),
                );
              },
              icon: const Icon(Icons.copy_all),
            ),
            IconButton(
              tooltip: 'Global Audit Log',
              color: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuditLogPage()),
                );
              },
              icon: const Icon(Icons.history_edu),
            ),
          ] else
            PopupMenuButton<int>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 0) setState(() => _isKanbanView = false);
                if (value == 1) setState(() => _isKanbanView = true);
                if (value == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DuplicateDetectionPage(),
                    ),
                  );
                }
                if (value == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuditLogPage(),
                    ),
                  );
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 0,
                      child: ListTile(
                        leading: Icon(Icons.table_rows),
                        title: Text('Table View'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: ListTile(
                        leading: Icon(Icons.view_kanban),
                        title: Text('Kanban View'),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 2,
                      child: ListTile(
                        leading: Icon(Icons.copy_all),
                        title: Text('Duplicates'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 3,
                      child: ListTile(
                        leading: Icon(Icons.history_edu),
                        title: Text('Audit Log'),
                      ),
                    ),
                  ],
            ),
          IconButton(
            tooltip: 'Toggle date sort',
            color: Colors.white,
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Record'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16).copyWith(bottom: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection:
                                  isSmallScreen
                                      ? Axis.horizontal
                                      : Axis.vertical,
                              child:
                                  isSmallScreen
                                      ? Row(
                                        children: [
                                          _MetricTile(
                                            label: 'Total Records',
                                            value: '${records.length}',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Won Pipeline',
                                            value:
                                                'KES ${_pipelineValue.toStringAsFixed(0)}',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Daily Perf.',
                                            value:
                                                '${_dailyPerformance['percent'] ?? '-'}%',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Weekly Perf.',
                                            value:
                                                '${_weeklyPerformance['percent'] ?? '-'}%',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Monthly Perf.',
                                            value:
                                                '${_monthlyPerformance['percent'] ?? '-'}%',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Yearly Perf.',
                                            value:
                                                '${_yearlyPerformance['percent'] ?? '-'}%',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Leads',
                                            value: '${_countByStage('Lead')}',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'Proposals',
                                            value:
                                                '${_countByStage('Proposal')}',
                                          ),
                                          const SizedBox(width: 10),
                                          _MetricTile(
                                            label: 'High Risk',
                                            value: '$_atRiskCount',
                                          ),
                                        ],
                                      )
                                      : Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _MetricTile(
                                            label: 'Total Records',
                                            value: '${records.length}',
                                          ),
                                          _MetricTile(
                                            label: 'Won Pipeline',
                                            value:
                                                'KES ${_pipelineValue.toStringAsFixed(0)}',
                                          ),
                                          _MetricTile(
                                            label: 'Daily Perf.',
                                            value:
                                                '${_dailyPerformance['percent'] ?? '-'}%',
                                          ),
                                          _MetricTile(
                                            label: 'Weekly Perf.',
                                            value:
                                                '${_weeklyPerformance['percent'] ?? '-'}%',
                                          ),
                                          _MetricTile(
                                            label: 'Monthly Perf.',
                                            value:
                                                '${_monthlyPerformance['percent'] ?? '-'}%',
                                          ),
                                          _MetricTile(
                                            label: 'Yearly Perf.',
                                            value:
                                                '${_yearlyPerformance['percent'] ?? '-'}%',
                                          ),
                                          _MetricTile(
                                            label: 'Leads',
                                            value: '${_countByStage('Lead')}',
                                          ),
                                          _MetricTile(
                                            label: 'Proposals',
                                            value:
                                                '${_countByStage('Proposal')}',
                                          ),
                                          _MetricTile(
                                            label: 'High Risk',
                                            value: '$_atRiskCount',
                                          ),
                                        ],
                                      ),
                            ),
                            const SizedBox(height: 14),
                            isSmallScreen
                                ? Column(
                                  children: [
                                    TextField(
                                      controller: _searchController,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText:
                                            'Search by school, contact, owner or notes',
                                        prefixIcon: const Icon(Icons.search),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedStage,
                                        items:
                                            _stages
                                                .map(
                                                  (stage) => DropdownMenuItem(
                                                    value: stage,
                                                    child: Text(stage),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(
                                              () => _selectedStage = value,
                                            );
                                          }
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Stage',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search by school, contact, owner or notes',
                                          prefixIcon: const Icon(Icons.search),
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 180,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedStage,
                                        items:
                                            _stages
                                                .map(
                                                  (stage) => DropdownMenuItem(
                                                    value: stage,
                                                    child: Text(stage),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(
                                              () => _selectedStage = value,
                                            );
                                          }
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Stage',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      records.isEmpty
                          ? const Center(
                            child: Text('No CRM records match filters'),
                          )
                          : _isKanbanView && isDesktop
                          ? _buildKanbanView(records)
                          : isDesktop
                          ? _buildDesktopDataTable(records)
                          : _buildResponsiveListView(records),
                ),
              ),
    );
  }

  Widget _buildDesktopDataTable(List<_CrmRecord> records) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('School')),
            DataColumn(label: Text('Map')),
            DataColumn(label: Text('Score')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Stage')),
            DataColumn(label: Text('Owner')),
            DataColumn(label: Text('Deal Value')),
            DataColumn(label: Text('Prob%')),
            DataColumn(label: Text('Next Action')),
            DataColumn(label: Text('Risk')),
            DataColumn(label: Text('Last Contact')),
            DataColumn(label: Text('Actions')),
          ],
          rows:
              records
                  .map(
                    (record) => DataRow(
                      cells: [
                        DataCell(
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => SchoolProfilePage(
                                        schoolId: record.schoolId,
                                      ),
                                ),
                              );
                            },
                            child: Text(
                              record.school,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          record.isMapped
                              ? const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 18,
                              )
                              : Tooltip(
                                message:
                                    'Missing GPS: Not visible on Dashboard Map',
                                child: const Icon(
                                  Icons.location_off,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                        ),
                        DataCell(
                          Text(
                            record.leadScore.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  record.leadScore >= 70
                                      ? Colors.green
                                      : record.leadScore >= 40
                                      ? Colors.orange
                                      : Colors.grey,
                            ),
                          ),
                        ),
                        DataCell(Text(record.contact)),
                        DataCell(Text(record.phone)),
                        DataCell(_StageChip(stage: record.stage)),
                        DataCell(Text(record.owner)),
                        DataCell(Text(_formatDealValue(record))),
                        DataCell(Text('${record.probability}%')),
                        DataCell(
                          Text(
                            '${record.nextActionDate.year}-${record.nextActionDate.month.toString().padLeft(2, '0')}-${record.nextActionDate.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        DataCell(
                          Text(
                            record.riskLevel,
                            style: TextStyle(
                              color:
                                  record.riskLevel == 'High'
                                      ? Colors.red
                                      : record.riskLevel == 'Medium'
                                      ? Colors.orange
                                      : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${record.lastContact.year}-${record.lastContact.month.toString().padLeft(2, '0')}-${record.lastContact.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit',
                                onPressed: () => _openEditDialog(record),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                                onPressed: () {
                                  ApiService().delete('school_sales', record.id)
                                      .then((_) {
                                        _loadCrmData();
                                      });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  Widget _buildResponsiveListView(List<_CrmRecord> records) {
    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  SchoolProfilePage(schoolId: record.schoolId),
                        ),
                      );
                    },
                    child: Text(
                      record.school,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                if (!record.isMapped)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.location_off,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
              ],
            ),
            subtitle: Text('${record.stage} • ${_formatDealValue(record)}'),
            leading: _StageChip(stage: record.stage),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Owner', record.owner),
                    _infoRow('Lead Score', record.leadScore.toString()),
                    _infoRow('Probability', '${record.probability}%'),
                    _infoRow('Risk Level', record.riskLevel),
                    _infoRow(
                      'Last Contact',
                      '${record.lastContact.year}-${record.lastContact.month.toString().padLeft(2, '0')}-${record.lastContact.day}',
                    ),
                    _infoRow(
                      'Next Action',
                      '${record.nextActionDate.year}-${record.nextActionDate.month.toString().padLeft(2, '0')}-${record.nextActionDate.day}',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openEditDialog(record),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            ApiService().delete('school_sales', record.id)
                                .then((_) => _loadCrmData());
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  int _probabilityByStage(String stage) {
    switch (stage) {
      case 'Lead':
        return 15;
      case 'Qualified':
        return 35;
      case 'Proposal':
        return 65;
      case 'Negotiation':
        return 80;
      case 'Won':
        return 100;
      case 'Lost':
        return 0;
      default:
        return 20;
    }
  }

  String _toDbStage(String uiStage) {
    switch (uiStage) {
      case 'Lead':
        return 'lead';
      case 'Qualified':
        return 'contacted';
      case 'Proposal':
        return 'quotation_sent';
      case 'Negotiation':
        return 'negotiation';
      case 'Won':
        return 'won';
      case 'Lost':
        return 'lost';
      default:
        return 'lead';
    }
  }

  String _fromDbStage(String dbStage) {
    switch (dbStage) {
      case 'lead':
        return 'Lead';
      case 'contacted':
      case 'meeting_scheduled':
      case 'sample_issued':
      case 'decision_pending':
        return 'Qualified';
      case 'quotation_sent':
        return 'Proposal';
      case 'negotiation':
        return 'Negotiation';
      case 'won':
        return 'Won';
      case 'lost':
        return 'Lost';
      default:
        return 'Lead';
    }
  }

  Widget _buildKanbanView(List<_CrmRecord> records) {
    final stages = _stages.where((s) => s != 'All').toList();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: stages.length,
      separatorBuilder: (context, index) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final stage = stages[index];
        final stageRecords = records.where((r) => r.stage == stage).toList();
        return _buildKanbanColumn(stage, stageRecords);
      },
    );
  }

  Widget _buildKanbanColumn(String stage, List<_CrmRecord> stageRecords) {
    final totalValue = stageRecords.fold(0.0, (sum, r) => sum + r.dealValue);
    final formattedTotalValue =
        stage == 'Won'
            ? 'KES ${totalValue.toStringAsFixed(0)}'
            : totalValue.toStringAsFixed(0);
    return DragTarget<_CrmRecord>(
      onAcceptWithDetails: (details) async {
        final record = details.data;
        if (record.stage == stage) return;

        setState(() {
          record.stage = stage;
          record.lastContact = DateTime.now();
        });

        try {
          await ApiService().patch('school_sales', record.id, {
                'sale_status': _toDbStage(stage),
                'probability': _probabilityByStage(stage),
                'stage_updated_at': DateTime.now().toIso8601String(),
              });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update stage: $e')),
            );
          }
          _loadCrmData();
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  candidateData.isNotEmpty ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        stage,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stageRecords.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  formattedTotalValue,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: stageRecords.length,
                  itemBuilder: (context, index) {
                    return _buildKanbanCard(stageRecords[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(_CrmRecord record) {
    final riskColor = switch (record.riskLevel) {
      'High' => Colors.red,
      'Medium' => Colors.orange,
      _ => Colors.green,
    };

    return Draggable<_CrmRecord>(
      data: record,
      feedback: SizedBox(
        width: 280,
        child: Opacity(opacity: 0.8, child: _cardContent(record, riskColor)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _cardContent(record, riskColor),
      ),
      child: _cardContent(record, riskColor),
    );
  }

  Widget _cardContent(_CrmRecord record, Color riskColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: riskColor.withValues(alpha: 0.5), width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => SchoolProfilePage(schoolId: record.schoolId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.school,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (record.leadScore >= 70
                          ? Colors.green
                          : record.leadScore >= 40
                          ? Colors.orange
                          : Colors.grey)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Lead Score: ${record.leadScore}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color:
                        record.leadScore >= 70
                            ? Colors.green
                            : record.leadScore >= 40
                            ? Colors.orange
                            : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDealValue(record),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${record.probability}%',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record.owner,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.event, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Next: ${record.nextActionDate.year}-${record.nextActionDate.month.toString().padLeft(2, '0')}-${record.nextActionDate.day.toString().padLeft(2, '0')}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      width: width < 720 ? 132 : 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final color = switch (stage) {
      'Lead' => Colors.blue,
      'Qualified' => Colors.orange,
      'Proposal' => Colors.purple,
      'Negotiation' => Colors.teal,
      'Won' => Colors.green,
      'Lost' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        stage,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CrmRecord {
  _CrmRecord({
    required this.id,
    required this.schoolId,
    required this.ownerId,
    required this.school,
    required this.contact,
    required this.phone,
    required this.stage,
    required this.owner,
    required this.dealValue,
    required this.lastContact,
    required this.nextActionDate,
    required this.probability,
    required this.notes,
    required this.leadScore,
    this.latitude,
    this.longitude,
  });

  String id;
  String schoolId;
  String? ownerId;
  String school;
  String contact;
  String phone;
  String stage;
  String owner;
  double dealValue;
  DateTime lastContact;
  DateTime nextActionDate;
  int probability;
  String notes;
  int leadScore;
  double? latitude;
  double? longitude;

  bool get isMapped => latitude != null && longitude != null;

  String get riskLevel {
    final now = DateTime.now();
    final daysSinceContact = now.difference(lastContact).inDays;
    final daysToAction = nextActionDate.difference(now).inDays;
    if (stage == 'Won' || stage == 'Lost') return 'Low';
    if (daysSinceContact > 7 || daysToAction < 0) return 'High';
    if (daysSinceContact > 3 || daysToAction <= 1) return 'Medium';
    return 'Low';
  }
}
