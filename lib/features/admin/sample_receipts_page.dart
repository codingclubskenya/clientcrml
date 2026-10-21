import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../services/api_service.dart';

class SampleReceiptsPage extends StatefulWidget {
  const SampleReceiptsPage({super.key});

  @override
  State<SampleReceiptsPage> createState() => _SampleReceiptsPageState();
}

class _SampleReceiptsPageState extends State<SampleReceiptsPage> {

  bool _isLoading = true;
  bool _isDemoData = false;
  String? _error;
  List<Map<String, dynamic>> _receiptRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _schoolRows = <Map<String, dynamic>>[];
  DateTimeRange? _dateRange;
  String? _countyFilter;
  bool _showRoiSection = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final receiptsRes = await ApiService().getAll(
        'school_sample_distributions', orderBy: 'distributed_at',
        orderDir: 'DESC', limit: 300,
      );

      final schoolsRes = await ApiService().getAll(
        'schools', orderBy: 'created_at', orderDir: 'DESC', limit: 400,
      );
      final usersRes = await ApiService().getAll('users', limit: 500);

      final ordersRes = await ApiService().getAll(
        'orders', orderBy: 'created_at', orderDir: 'DESC', limit: 500,
      );

      final salesRes = await ApiService().getAll(
        'school_sales', orderBy: 'created_at', orderDir: 'DESC', limit: 500,
      );

      final receiptRows = List<Map<String, dynamic>>.from(receiptsRes);
      final schoolById = {
        for (final school in schoolsRes) school['id'].toString(): school,
      };
      final userById = {
        for (final user in usersRes) user['id'].toString(): user,
      };
      for (final row in receiptRows) {
        final schoolId = row['school_id']?.toString();
        final agentId = row['agent_id']?.toString();
        row['schools'] = schoolById[schoolId];
        row['users'] = userById[agentId];
      }
      if (!mounted) return;

      final demoMode = receiptRows.isEmpty;
      final seededReceipts = demoMode ? _demoReceipts() : receiptRows;
      final seededSchools =
          demoMode
              ? _demoSchools()
              : List<Map<String, dynamic>>.from(schoolsRes);
      final seededOrders =
          demoMode
              ? _demoOrders()
              : List<Map<String, dynamic>>.from(ordersRes);
      final seededSales =
          demoMode
              ? _demoSales()
              : List<Map<String, dynamic>>.from(salesRes);

      setState(() {
        _isDemoData = demoMode;
        _receiptRows = seededReceipts;
        _schoolRows = seededSchools;
        _ordersCache = seededOrders;
        _salesCache = seededSales;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load photos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolById = <String, Map<String, dynamic>>{
      for (final row in _schoolRows)
        if ((row['id']?.toString() ?? '').isNotEmpty) row['id'].toString(): row,
    };

    final filteredReceipts =
        _receiptRows.where((row) {
          final schoolId = row['school_id']?.toString() ?? '';
          final school = schoolById[schoolId];
          if (_countyFilter != null && _countyFilter!.trim().isNotEmpty) {
            final county = school?['county']?.toString() ?? '';
            if (county.toLowerCase() != _countyFilter!.toLowerCase()) {
              return false;
            }
          }
          if (_dateRange != null) {
            final raw = row['distributed_at']?.toString();
            final when = raw == null ? null : DateTime.tryParse(raw);
            if (when == null) return false;
            final start = DateTime(
              _dateRange!.start.year,
              _dateRange!.start.month,
              _dateRange!.start.day,
            );
            final end = DateTime(
              _dateRange!.end.year,
              _dateRange!.end.month,
              _dateRange!.end.day,
              23,
              59,
              59,
            );
            if (when.isBefore(start) || when.isAfter(end)) return false;
          }
          return true;
        }).toList();

    final filteredSchools =
        _schoolRows.where((row) {
          if (_countyFilter == null || _countyFilter!.trim().isEmpty) {
            return true;
          }
          final county = row['county']?.toString() ?? '';
          return county.toLowerCase() == _countyFilter!.toLowerCase();
        }).toList();

    final schoolPhotos =
        filteredSchools
            .where(
              (row) =>
                  (row['photo_url']?.toString().trim().isNotEmpty ?? false),
            )
            .toList();
    final sampleProofPhotos =
        filteredSchools
            .where(
              (row) =>
                  (row['sample_proof_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();
    final stampedReceipts =
        filteredReceipts
            .where(
              (row) =>
                  (row['stamped_receipt_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();
    final roiRows = _buildRoiRows(filteredReceipts, _ordersCache, _salesCache);
    final hasRoiData = roiRows.isNotEmpty;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('All Photos'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'School Photos'),
              Tab(text: 'Sample Proofs'),
              Tab(text: 'Stamped Receipts'),
            ],
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
                : Column(
                  children: [
                    _buildFiltersBar(),
                    if (_isDemoData)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPale,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Demo data is being shown because no sample receipts were found.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (hasRoiData) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showRoiSection = !_showRoiSection;
                              });
                            },
                            icon: Icon(
                              _showRoiSection
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text(
                              _showRoiSection
                                  ? 'Hide ROI by Person'
                                  : 'Show ROI by Person',
                            ),
                          ),
                        ),
                      ),
                      if (_showRoiSection) _buildRoiSection(roiRows),
                    ],
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: TabBarView(
                          children: [
                            _buildSchoolPhotoGrid(schoolPhotos),
                            _buildSampleProofGrid(sampleProofPhotos),
                            _buildReceiptsList(stampedReceipts),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFiltersBar() {
    final counties =
        _schoolRows
            .map((e) => (e['county']?.toString() ?? '').trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _dateRange == null
                  ? 'Date Range'
                  : '${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')} -> ${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}',
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String?>(
              initialValue: _countyFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'County',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Counties'),
                ),
                ...counties.map(
                  (c) => DropdownMenuItem<String?>(value: c, child: Text(c)),
                ),
              ],
              onChanged: (value) => setState(() => _countyFilter = value),
            ),
          ),
          if (_dateRange != null || _countyFilter != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _dateRange = null;
                  _countyFilter = null;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildRoiSection(List<_RoiRow> rows) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ROI By Person',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Samples given, schools reached, revenue earned.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                child: Text(
                  row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                ),
              ),
              title: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Samples: ${row.samplesGiven} • Schools: ${row.schoolsReached} • Revenue: KES ${row.revenueEarned.toStringAsFixed(0)}',
              ),
              trailing: Text(
                'Won: ${row.wonValue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolPhotoGrid(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No school photos found.'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200)
      crossAxisCount = 5;
    else if (screenWidth > 900)
      crossAxisCount = 4;
    else if (screenWidth > 600)
      crossAxisCount = 3;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final url = row['photo_url']?.toString() ?? '';
        final schoolName = row['name']?.toString() ?? 'School';
        final county = row['county']?.toString() ?? 'Unknown County';
        return _photoCard(url: url, title: schoolName, subtitle: county);
      },
    );
  }

  Widget _buildSampleProofGrid(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No stamped sample proof photos found.'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200)
      crossAxisCount = 5;
    else if (screenWidth > 900)
      crossAxisCount = 4;
    else if (screenWidth > 600)
      crossAxisCount = 3;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final url = row['sample_proof_url']?.toString() ?? '';
        final schoolName = row['name']?.toString() ?? 'School';
        return _photoCard(
          url: url,
          title: schoolName,
          subtitle: 'Stamped Document',
        );
      },
    );
  }

  Widget _buildReceiptsList(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No stamped sample receipts found.'));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final crossAxisCount =
        screenWidth > 1200
            ? 4
            : (screenWidth > 900 ? 3 : (screenWidth > 600 ? 2 : 1));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 0.9 : 1.1,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final schoolName =
            row['schools']?['name']?.toString() ?? 'Unknown School';
        final schoolId = row['school_id']?.toString() ?? '';
        final sampleName = row['sample_name']?.toString() ?? 'Sample';
        final qty = row['quantity']?.toString() ?? '1';
        final url = row['stamped_receipt_url']?.toString() ?? '';

        final hasActiveSale = _salesCache.any(
          (s) => s['school_id']?.toString() == schoolId,
        );

        return Card(
          elevation: 2,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$sampleName -> $schoolName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasActiveSale)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'CRM Linked',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Qty: $qty'),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => _openPreview(url),
                      child: Image.network(
                        url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text(
                                'Could not load receipt image',
                                textAlign: TextAlign.center,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoCard({
    required String url,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () => _openPreview(url),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('Could not load'),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.longhornMaroon,
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

  void _openPreview(String url) {
    showDialog<void>(
      context: context,
      builder:
          (_) => Dialog(child: InteractiveViewer(child: Image.network(url))),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      helpText: 'Filter ROI By Date',
    );
    if (picked == null) return;
    setState(() => _dateRange = picked);
  }

  List<Map<String, dynamic>> _ordersCache = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _salesCache = <Map<String, dynamic>>[];

  List<_RoiRow> _buildRoiRows(
    List<Map<String, dynamic>> receiptRows,
    List<Map<String, dynamic>> orderRows,
    List<Map<String, dynamic>> salesRows,
  ) {
    final byAgent = <String, _RoiAccumulator>{};

    for (final row in receiptRows) {
      final agentId = row['agent_id']?.toString() ?? '';
      if (agentId.isEmpty) continue;
      final user = row['users'] as Map<String, dynamic>?;
      final displayName =
          user?['full_name']?.toString().trim().isNotEmpty == true
              ? user!['full_name'].toString().trim()
              : (user?['email']?.toString() ?? 'Unknown User');
      final qty = (row['quantity'] as num?)?.toInt() ?? 1;
      final schoolId = row['school_id']?.toString() ?? '';

      final acc = byAgent.putIfAbsent(
        agentId,
        () => _RoiAccumulator(displayName),
      );
      acc.samples += qty;
      if (schoolId.isNotEmpty) {
        acc.schools.add(schoolId);
      }
    }

    for (final row in orderRows) {
      final agentId = row['agent_id']?.toString() ?? '';
      if (agentId.isEmpty || !byAgent.containsKey(agentId)) continue;
      final status = (row['status']?.toString().toLowerCase() ?? '');
      if (status == 'approved' || status == 'paid') {
        final amount = (row['checkout_amount'] as num?)?.toDouble() ?? 0.0;
        byAgent[agentId]!.revenue += amount;
      }
    }

    for (final row in salesRows) {
      final agentId = row['agent_id']?.toString() ?? '';
      if (agentId.isEmpty || !byAgent.containsKey(agentId)) continue;
      final stage = (row['sale_status']?.toString().toLowerCase() ?? '');
      if (stage == 'won') {
        final amount = (row['expected_value'] as num?)?.toDouble() ?? 0.0;
        byAgent[agentId]!.won += amount;
      }
    }

    final rows =
        byAgent.entries
            .map(
              (entry) => _RoiRow(
                name: entry.value.name,
                samplesGiven: entry.value.samples,
                schoolsReached: entry.value.schools.length,
                revenueEarned: entry.value.revenue,
                wonValue: entry.value.won,
              ),
            )
            .toList()
          ..sort((a, b) => b.revenueEarned.compareTo(a.revenueEarned));

    return rows;
  }

  List<Map<String, dynamic>> _demoReceipts() {
    return [
      {
        'id': 'demo-receipt-1',
        'school_id': 'demo-school-1',
        'agent_id': 'demo-agent-1',
        'sample_name': 'Teacher Guide Kit',
        'sample_category': 'Reference',
        'quantity': 2,
        'notes': 'Demo receipt row',
        'distributed_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'stamped_receipt_url':
            'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1200',
        'stamped_receipt_path': 'demo/receipt_1.jpg',
        'schools': {'name': 'Bahati Primary School'},
        'users': {
          'full_name': 'Grounds Demo User',
          'email': 'grounds.demo@dehus.com',
        },
      },
      {
        'id': 'demo-receipt-2',
        'school_id': 'demo-school-2',
        'agent_id': 'demo-agent-2',
        'sample_name': 'Grade 1 Reader Pack',
        'sample_category': 'Primary',
        'quantity': 3,
        'notes': 'Demo receipt row',
        'distributed_at':
            DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'stamped_receipt_url':
            'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=1200',
        'stamped_receipt_path': 'demo/receipt_2.jpg',
        'schools': {'name': 'Mwangaza Academy'},
        'users': {
          'full_name': 'Agent Demo User',
          'email': 'agent.demo@dehus.com',
        },
      },
      {
        'id': 'demo-receipt-3',
        'school_id': 'demo-school-3',
        'agent_id': 'demo-agent-1',
        'sample_name': 'Assessment Bundle',
        'sample_category': 'Test',
        'quantity': 1,
        'notes': 'Demo receipt row',
        'distributed_at':
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'stamped_receipt_url':
            'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=1200',
        'stamped_receipt_path': 'demo/receipt_3.jpg',
        'schools': {'name': 'Kisumu West School'},
        'users': {
          'full_name': 'Grounds Demo User',
          'email': 'grounds.demo@dehus.com',
        },
      },
    ];
  }

  List<Map<String, dynamic>> _demoSchools() {
    return [
      {
        'id': 'demo-school-1',
        'name': 'Bahati Primary School',
        'county': 'Nakuru',
        'photo_url':
            'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=1200',
        'sample_proof_url':
            'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=1200',
        'created_at':
            DateTime.now().subtract(const Duration(days: 12)).toIso8601String(),
      },
      {
        'id': 'demo-school-2',
        'name': 'Mwangaza Academy',
        'county': 'Kisumu',
        'photo_url':
            'https://images.unsplash.com/photo-1498243691581-b145c3f54a5a?w=1200',
        'sample_proof_url':
            'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=1200',
        'created_at':
            DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      },
      {
        'id': 'demo-school-3',
        'name': 'Kisumu West School',
        'county': 'Kisumu',
        'photo_url':
            'https://images.unsplash.com/photo-1523580494863-6f3031224c94?w=1200',
        'sample_proof_url':
            'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=1200',
        'created_at':
            DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
    ];
  }

  List<Map<String, dynamic>> _demoOrders() {
    return [
      {
        'agent_id': 'demo-agent-1',
        'checkout_amount': 68000,
        'status': 'approved',
        'created_at':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'agent_id': 'demo-agent-2',
        'checkout_amount': 54000,
        'status': 'paid',
        'created_at':
            DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'agent_id': 'demo-agent-1',
        'checkout_amount': 42000,
        'status': 'pending',
        'created_at':
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
    ];
  }

  List<Map<String, dynamic>> _demoSales() {
    return [
      {
        'school_id': 'demo-school-1',
        'agent_id': 'demo-agent-1',
        'expected_value': 98000,
        'sale_status': 'won',
        'created_at':
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'school_id': 'demo-school-2',
        'agent_id': 'demo-agent-2',
        'expected_value': 76000,
        'sale_status': 'negotiation',
        'created_at':
            DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
      {
        'school_id': 'demo-school-3',
        'agent_id': 'demo-agent-1',
        'expected_value': 112000,
        'sale_status': 'won',
        'created_at':
            DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
      },
    ];
  }
}

class _RoiAccumulator {
  _RoiAccumulator(this.name);

  final String name;
  int samples = 0;
  final Set<String> schools = <String>{};
  double revenue = 0.0;
  double won = 0.0;
}

class _RoiRow {
  const _RoiRow({
    required this.name,
    required this.samplesGiven,
    required this.schoolsReached,
    required this.revenueEarned,
    required this.wonValue,
  });

  final String name;
  final int samplesGiven;
  final int schoolsReached;
  final double revenueEarned;
  final double wonValue;
}
