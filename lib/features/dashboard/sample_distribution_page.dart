import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../core/constants/colors.dart';
import '../../features/database/database_service.dart';
import '../admin/add_sample_book_page.dart';
import 'client_type_selector.dart';
import '../../models/catalog_item_model.dart';
import '../../models/farmer_model.dart';
import '../../services/api_service.dart';

class SampleDistributionPage extends StatefulWidget {
  const SampleDistributionPage({super.key});

  @override
  State<SampleDistributionPage> createState() => _SampleDistributionPageState();
}

class SampleMenuTile {
  const SampleMenuTile(this.id, this.label, this.icon, [this.onTap]);
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _SampleDistributionPageState extends State<SampleDistributionPage> {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _api = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  late Future<List<SchoolModel>> _schoolsFuture;
  String? _selectedSchoolId;
  final String _selectedCategory = "All";
  final String _selectedSampleName = "All";
  final String _searchQuery = "";
  int? _currentRole;
  final List<String> _distributionLog = [];
  List<CatalogItemModel> _samples = <CatalogItemModel>[];
  int _initialSampleTotal = 0;
  XFile? _recoveredLostPhoto;
  bool _isLoadingRoi = true;
  double _roiRevenue = 0.0;
  double _roiWonValue = 0.0;
  int _roiSamplesGiven = 0;
  int _roiSchoolsReached = 0;

  // --- Book Sample Request & Balance Tracking ---
  ClientType? _selectedClientType;
  List<Map<String, dynamic>> _distributions = <Map<String, dynamic>>[];
  bool _isLoadingDistributions = false;
  final Set<String> _requestSampleIds = <String>{};
  final Map<String, int> _requestQty = <String, int>{};
  final TextEditingController _requestNotesController = TextEditingController();
  final TextEditingController _requestSearchController =
      TextEditingController();
  String? _activeSection;
  String _requestSearchQuery = '';

  Future<void> _updateSampleCatalogItem({
    required CatalogItemModel sample,
    int? stockQty,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (stockQty != null) {
        payload['stock_qty'] = stockQty < 0 ? 0 : stockQty;
      }
      if (isActive != null) {
        payload['is_active'] = isActive;
      }
      if (payload.isEmpty) return;

      await _api.patch('catalog_items', sample.id, payload);

      await _loadSamples();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sample catalog updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update sample catalog: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _schoolsFuture = _dbService.getAllSchools();
    _loadCurrentRole();
    _loadSamples();
    _recoverLostCameraData();
    _loadRoiSummary();
    _loadDistributions();
  }

  @override
  void dispose() {
    _requestNotesController.dispose();
    _requestSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRole() async {
    final role = await _dbService.getCurrentUserRole();
    if (!mounted) return;
    setState(() => _currentRole = role);
  }

  Future<void> _refreshSchools() async {
    setState(() {
      _schoolsFuture = _dbService.getAllSchools();
    });
    await _loadSamples();
    await _loadRoiSummary();
    await _loadDistributions();
  }

  Future<void> _loadRoiSummary() async {
    setState(() => _isLoadingRoi = true);
    try {
      final api = ApiService();
      final userId = api.currentUserId;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _isLoadingRoi = false);
        return;
      }

      final receiptsRes = await api.getAll('school_sample_distributions', filter: {'agent_id': userId}, orderBy: 'distributed_at', orderDir: 'DESC', limit: 500);
      final ordersRes = await api.getAll('orders', filter: {'agent_id': userId}, orderBy: 'created_at', orderDir: 'DESC', limit: 500);
      final salesRes = await api.getAll('school_sales', filter: {'agent_id': userId}, orderBy: 'created_at', orderDir: 'DESC', limit: 500);

      int samplesGiven = 0;
      final schools = <String>{};
      for (final row in List<Map<String, dynamic>>.from(receiptsRes)) {
        samplesGiven += (row['quantity'] as num?)?.toInt() ?? 1;
        final schoolId = row['school_id']?.toString() ?? '';
        if (schoolId.isNotEmpty) schools.add(schoolId);
      }

      double revenue = 0.0;
      for (final row in List<Map<String, dynamic>>.from(ordersRes)) {
        final status = (row['status']?.toString().toLowerCase() ?? '');
        if (status == 'approved' || status == 'paid') {
          revenue += (row['checkout_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      double wonValue = 0.0;
      for (final row in List<Map<String, dynamic>>.from(salesRes)) {
        final stage = (row['sale_status']?.toString().toLowerCase() ?? '');
        if (stage == 'won') {
          wonValue += (row['expected_value'] as num?)?.toDouble() ?? 0.0;
        }
      }

      if (!mounted) return;
      setState(() {
        _roiSamplesGiven = samplesGiven;
        _roiSchoolsReached = schools.length;
        _roiRevenue = revenue;
        _roiWonValue = wonValue;
        _isLoadingRoi = false;
      });
    } catch (e) {
      debugPrint('Failed to load ROI summary: $e');
      if (!mounted) return;
      setState(() => _isLoadingRoi = false);
    }
  }

  Future<void> _loadDistributions() async {
    setState(() => _isLoadingDistributions = true);
    try {
      final userId = ApiService().currentUserId;
      final rows = await _dbService.getSampleDistributions(
        agentId: _currentRole == 1 ? null : userId,
        clientType: _selectedClientType?.value,
        schoolId: _selectedSchoolId,
      );
      if (!mounted) return;
      setState(() {
        _distributions = rows;
        _isLoadingDistributions = false;
      });
    } catch (e) {
      debugPrint('Failed to load sample distributions: $e');
      if (!mounted) return;
      setState(() => _isLoadingDistributions = false);
    }
  }

  void _toggleRequestSample(CatalogItemModel sample) {
    setState(() {
      if (_requestSampleIds.contains(sample.id)) {
        _requestSampleIds.remove(sample.id);
        _requestQty.remove(sample.id);
      } else {
        _requestSampleIds.add(sample.id);
        _requestQty[sample.id] = 1;
      }
    });
  }

  Future<void> _submitSampleRequest() async {
    final selected =
        _samples
            .where((s) => _requestSampleIds.contains(s.id))
            .where((s) => (_requestQty[s.id] ?? 0) > 0)
            .toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one book with a quantity.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Sample Request'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('You are requesting the following samples:'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: selected.length,
                      itemBuilder: (context, index) {
                        final s = selected[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('• ${s.name}')),
                              Text(
                                'Qty: ${_requestQty[s.id]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit Request'),
              ),
            ],
          ),
    );

    if (proceed != true) return;

    final notes = _requestNotesController.text.trim();
    try {
      final items =
          selected
              .map(
                (sample) => {
                  'sample_id': sample.id,
                  'sample_name': sample.name,
                  'sample_category': sample.category,
                  'requested_qty': _requestQty[sample.id]!,
                },
              )
              .toList();

      await _dbService.createSampleRequest(
        schoolId: _selectedSchoolId,
        items: items,
        clientType: _selectedClientType?.value,
        notes: notes.isEmpty ? null : notes,
      );

      setState(() {
        _requestSampleIds.clear();
        _requestQty.clear();
        _requestNotesController.clear();
      });
      await _loadDistributions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} sample request(s) recorded.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateReturnedQty(Map<String, dynamic> record) async {
    final id = record['id']?.toString() ?? '';
    final issued = (record['quantity'] as num?)?.toInt() ?? 0;
    int returned = (record['returned_qty'] as num?)?.toInt() ?? 0;
    final controller = TextEditingController(text: '$returned');
    final int? result = await showDialog<int>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Update Returned Samples'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Book: ${record['sample_name']} • Issued: $issued',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Returned quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final val = int.tryParse(controller.text);
                  if (val == null || val < 0) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context, val > issued ? issued : val);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (result == null) return;
    try {
      await _dbService.updateSampleReturnedQty(id, result);
      await _loadDistributions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Returned quantity updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredDistributions {
    return _distributions.where((row) {
      final matchesClientType =
          _selectedClientType == null ||
          (row['client_type']?.toString().toLowerCase() ?? '') ==
              _selectedClientType!.value.toLowerCase();
      final matchesSchool =
          _selectedSchoolId == null ||
          row['school_id']?.toString() == _selectedSchoolId;
      return matchesClientType && matchesSchool;
    }).toList();
  }

  Map<String, Map<String, int>> get _balanceByBook {
    final map = <String, Map<String, int>>{};
    for (final row in _filteredDistributions) {
      final name = row['sample_name']?.toString() ?? 'Unknown';
      final issued = (row['quantity'] as num?)?.toInt() ?? 0;
      final returned = (row['returned_qty'] as num?)?.toInt() ?? 0;
      final entry = map.putIfAbsent(name, () => {'issued': 0, 'returned': 0});
      entry['issued'] = (entry['issued'] ?? 0) + issued;
      entry['returned'] = (entry['returned'] ?? 0) + returned;
    }
    return map;
  }

  int get _totalIssued => _filteredDistributions.fold<int>(
    0,
    (sum, row) => sum + ((row['quantity'] as num?)?.toInt() ?? 0),
  );

  int get _totalReturned => _filteredDistributions.fold<int>(
    0,
    (sum, row) => sum + ((row['returned_qty'] as num?)?.toInt() ?? 0),
  );

  int get _totalRemaining => _totalIssued - _totalReturned;

  Widget _buildMenuGrid() {
    final tiles = <SampleMenuTile>[
      SampleMenuTile('request', 'Request Samples', Icons.playlist_add_check),
      SampleMenuTile('balance', 'Balance Tracking', Icons.balance),
      SampleMenuTile('catalog', 'Sample Catalog', Icons.menu_book),
      SampleMenuTile('roi', 'My ROI', Icons.trending_up),
      SampleMenuTile('history', 'Recent Activity', Icons.history),
      SampleMenuTile(
        'photos',
        'All Photos',
        Icons.photo_library_outlined,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SampleProofGalleryPage(),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossCount =
            width >= 900
                ? 4
                : width >= 600
                ? 3
                : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: width >= 600 ? 1.7 : 1.5,
          children:
              tiles.map((tile) {
                final isActive = _activeSection == tile.id;
                return InkWell(
                  onTap:
                      tile.onTap ??
                      () => setState(() => _activeSection = tile.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          isActive
                              ? Border.all(
                                color: AppColors.primaryGreen,
                                width: 2,
                              )
                              : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            tile.icon,
                            color: AppColors.primaryGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tile.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Widget _buildActiveSection(bool compact, List<SchoolModel> schools) {
    final children = <Widget>[];
    switch (_activeSection) {
      case 'request':
        children.add(_buildRequestForm(schools));
      case 'balance':
        children.add(_buildBalanceSection(compact: compact));
      case 'catalog':
        if (_currentRole == 1) {
          children.add(_buildAdminSampleCatalogManager());
          children.add(SizedBox(height: compact ? 12 : 16));
        }
        children.addAll([
          _buildSchoolSelector(schools),
          SizedBox(height: compact ? 12 : 16),
        ]);
        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Samples',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._filteredSamples().map(
                (sample) => _buildSampleCard(sample, schools),
              ),
            ],
          ),
        );
      case 'roi':
        children.addAll([
          _buildRoiSummaryCard(compact: compact),
          SizedBox(height: compact ? 12 : 16),
          _buildRemainingTracker(compact: compact),
        ]);
      case 'history':
        children.add(_buildHistory());
      default:
        children.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _activeSection = null),
            icon: const Icon(Icons.close),
            label: const Text('Close'),
          ),
        ),
        ...children,
      ],
    );
  }

  Future<void> _loadSamples() async {
    final samples = await _dbService.getSampleCatalogItemsFromTable();
    if (!mounted) return;
    setState(() {
      _samples = samples;
      if (_initialSampleTotal == 0) {
        _initialSampleTotal = samples.fold<int>(
          0,
          (sum, sample) => sum + sample.stockQty,
        );
      }
    });
  }

  Future<void> _recoverLostCameraData() async {
    try {
      final lostData = await _imagePicker.retrieveLostData();
      if (lostData.isEmpty || lostData.file == null) return;
      if (!mounted) return;
      setState(() {
        _recoveredLostPhoto = lostData.file;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recovered a previously captured photo.')),
      );
    } catch (e) {
      debugPrint('Failed to recover lost camera data: $e');
    }
  }

  Future<XFile?> _takeProofPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return photo;
    } on PlatformException catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera error: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _assignSample({
    required CatalogItemModel sample,
    required SchoolModel school,
  }) async {
    if (sample.stockQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That sample is out of stock.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int quantity = 1;
    final qtyController = TextEditingController(text: '1');
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Distribute ${sample.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('To: ${school.name}'),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final val = int.tryParse(qtyController.text);
                  if (val != null && val > 0 && val <= sample.stockQty) {
                    quantity = val;
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid quantity or not enough stock.'),
                      ),
                    );
                  }
                },
                child: const Text('Capture Proof'),
              ),
            ],
          ),
    );

    if (proceed != true) return;

    final proofPhoto = await _captureStampedPaperProof(
      sampleName: sample.name,
      schoolName: school.name,
    );
    if (proofPhoto == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Distribution cancelled: proof photo is required.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Uploading proof and updating CRM...')),
              ],
            ),
          ),
    );

    final receiptUpload = await _uploadStampedReceipt(
      photo: proofPhoto,
      sampleName: sample.name,
      schoolName: school.name,
    );

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    if ((receiptUpload['url'] ?? '').trim().isEmpty) {
      final reason =
          (receiptUpload['error'] ?? '').trim().isEmpty
              ? 'Could not upload stamped receipt photo. Try again.'
              : 'Photo upload failed: ${receiptUpload['error']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      final index = _samples.indexWhere((item) => item.id == sample.id);
      if (index != -1) {
        _samples[index] = CatalogItemModel(
          id: sample.id,
          name: sample.name,
          category: sample.category,
          sku: sample.sku,
          itemType: sample.itemType,
          unitPrice: sample.unitPrice,
          stockQty: sample.stockQty - quantity,
          description: sample.description,
          isActive: sample.isActive,
          isSynced: sample.isSynced,
          createdAt: sample.createdAt,
          updatedAt: sample.updatedAt,
        );
      }
      _distributionLog.insert(
        0,
        '$quantity x ${sample.name} given to ${school.name} (proof captured)',
      );
      if (_distributionLog.length > 5) {
        _distributionLog.removeLast();
      }
    });

    try {
      await _dbService.recordSampleDistribution(
        schoolId: school.id,
        sampleName: sample.name,
        sampleCategory: sample.category,
        clientType: _selectedClientType?.value,
        quantity: quantity,
        notes: 'Distributed from Sample Distribution page.',
        stampedReceiptUrl: receiptUpload['url'],
        stampedReceiptPath: receiptUpload['path'],
      );
      await _dbService.decrementCatalogStock(sample.id, quantity);

      // App-level CRM Automation (Fallback if SQL Trigger is not active)
      final saleRows = await _api.getAll('school_sales', filter: {'school_id': school.id}, orderBy: 'created_at', orderDir: 'DESC', limit: 1);
      final saleRes = saleRows.isEmpty ? null : saleRows.first;

      if (saleRes != null) {
        final saleId = saleRes['id'];
        final currentStatus = saleRes['sale_status']?.toString().toLowerCase();

        if (currentStatus == 'lead' ||
            currentStatus == 'contacted' ||
            currentStatus == 'meeting_scheduled') {
          await _api.patch('school_sales', saleId.toString(), {
                'sale_status': 'sample_issued',
                'stage_updated_at': DateTime.now().toIso8601String(),
              });
        }

        await _api.create('opportunity_activities', {
          'opportunity_id': saleId,
          'school_id': school.id,
          'actor_id': _api.currentUserId,
          'activity_type': 'Sample Delivered',
          'activity_outcome': 'Samples left with school',
          'notes': 'Distributed $quantity x ${sample.name}',
          'next_action': 'Follow up on sample',
          'next_action_date':
              DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save distribution: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantity x ${sample.name} assigned to ${school.name}'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<XFile?> _captureStampedPaperProof({
    required String sampleName,
    required String schoolName,
  }) async {
    XFile? capturedPhoto = _recoveredLostPhoto;
    Uint8List? capturedPhotoBytes;
    if (capturedPhoto != null) {
      capturedPhotoBytes = await capturedPhoto.readAsBytes();
      _recoveredLostPhoto = null;
    }

    if (!mounted) return null;
    final result = await showDialog<XFile?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Capture Stamped Paper Proof'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Take a clear photo of the stamped instruction paper for:',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$sampleName -> $schoolName',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (capturedPhoto == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No photo captured yet.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 180,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey.shade100,
                          ),
                          child:
                              capturedPhotoBytes == null
                                  ? const Center(
                                    child: Text('Preview unavailable'),
                                  )
                                  : Image.memory(
                                    capturedPhotoBytes!,
                                    fit: BoxFit.cover,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed:
                                capturedPhotoBytes == null
                                    ? null
                                    : () {
                                      showDialog<void>(
                                        context: context,
                                        builder:
                                            (_) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.memory(
                                                  capturedPhotoBytes!,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                      );
                                    },
                            icon: const Icon(Icons.open_in_full),
                            label: const Text('View Photo'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can retake the photo before continuing.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final photo = await _takeProofPhoto();
                    if (photo == null) return;
                    final bytes = await photo.readAsBytes();
                    setModalState(() {
                      capturedPhoto = photo;
                      capturedPhotoBytes = bytes;
                    });
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    capturedPhoto == null ? 'Capture Photo' : 'Retake',
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      capturedPhoto == null
                          ? null
                          : () => Navigator.pop(context, capturedPhoto),
                  child: const Text('Use Photo'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<Map<String, String?>> _uploadStampedReceipt({
    required XFile photo,
    required String sampleName,
    required String schoolName,
  }) async {
    final api = ApiService();
    final rawExt = photo.path.split('.').last.toLowerCase();
    final fileExt = rawExt.isEmpty || rawExt.length > 5 ? 'jpg' : rawExt;
    final safeSchool = schoolName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final safeSample = sampleName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    final fileName =
        'sample_receipts/${safeSchool}_${safeSample}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    try {
      final bytes = await photo.readAsBytes();
      final candidateBuckets = ['schools', 'profiles'];
      String? lastError;

      for (final bucket in candidateBuckets) {
        try {
          final uploadedUrl = await api.uploadFile(bucket: bucket, fileName: fileName, bytes: bytes);
          if (uploadedUrl == null) throw Exception('Upload failed');

          return {
            'url': uploadedUrl,
            'path': fileName,
            'error': null,
          };
        } catch (e) {
          lastError = '$bucket: $e';
        }
      }

      return {'url': null, 'path': null, 'error': lastError};
    } catch (e) {
      debugPrint('Stamped receipt upload failed: $e');
      return {'url': null, 'path': null, 'error': e.toString()};
    }
  }

  List<CatalogItemModel> _filteredSamples() {
    return _samples.where((sample) {
      final matchesCategory =
          _selectedCategory == "All" || sample.category == _selectedCategory;
      final matchesName =
          _selectedSampleName == "All" || sample.name == _selectedSampleName;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          sample.name.toLowerCase().contains(q) ||
          (sample.description ?? '').toLowerCase().contains(q);
      return matchesCategory && matchesName && matchesSearch;
    }).toList();
  }

  int get _remainingSampleTotal =>
      _samples.fold<int>(0, (sum, sample) => sum + sample.stockQty);

  int get _distributedSampleTotal =>
      _initialSampleTotal - _remainingSampleTotal;

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (_currentRole) {
      1 => 'Admin',
      2 => 'Sales Manager',
      3 => 'BAS',
      4 => 'Agent',
      5 => 'Grounds Person',
      _ => 'User',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text('Sample Distribution'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            tooltip: 'All Photos',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SampleProofGalleryPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSchools,
          ),
        ],
      ),
      body: FutureBuilder<List<SchoolModel>>(
        future: _schoolsFuture,
        builder: (context, snapshot) {
          final schools = snapshot.data ?? const <SchoolModel>[];
          return LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              final hGap = isCompact ? 12.0 : 16.0;
              final vGap = isCompact ? 12.0 : 16.0;
              final filteredSchools =
                  _selectedClientType == null
                      ? schools
                      : schools
                          .where(
                            (s) =>
                                clientTypeFromValue(s.dealerType) ==
                                _selectedClientType,
                          )
                          .toList();
              return ListView(
                padding: EdgeInsets.all(hGap),
                children: [
                  _buildClientTypeFilter(),
                  SizedBox(height: vGap),
                  _buildHeader(roleLabel, compact: isCompact),
                  SizedBox(height: vGap),
                  _buildMenuGrid(),
                  SizedBox(height: vGap),
                  if (_activeSection != null)
                    _buildActiveSection(isCompact, filteredSchools)
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 36,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Select an option above to get started.',
                            style: TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(String roleLabel, {required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.accentOrange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role: $roleLabel',
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 12 : 13,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Select a school, pick a sample, and hand it over from one screen.',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSampleCatalogManager() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin: Manage Sample Catalog',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Edit stock and active status for sample items in catalog_items.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddSampleBookPage(),
                  ),
                );
                await _loadSamples();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Sample'),
            ),
          ),
          const SizedBox(height: 10),
          if (_samples.isEmpty)
            const Text('No sample catalog items found.')
          else
            ..._samples.map((sample) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sample.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${sample.sku} • ${sample.category}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed:
                              () => _updateSampleCatalogItem(
                                sample: sample,
                                stockQty: sample.stockQty - 1,
                              ),
                          child: const Text('-1'),
                        ),
                        Text(
                          'Stock: ${sample.stockQty}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        OutlinedButton(
                          onPressed:
                              () => _updateSampleCatalogItem(
                                sample: sample,
                                stockQty: sample.stockQty + 1,
                              ),
                          child: const Text('+1'),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Active'),
                            Switch(
                              value: sample.isActive,
                              onChanged:
                                  (value) => _updateSampleCatalogItem(
                                    sample: sample,
                                    isActive: value,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRoiSummaryCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child:
          _isLoadingRoi
              ? const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Sample ROI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Wrap(
                    spacing: compact ? 8 : 10,
                    runSpacing: compact ? 8 : 10,
                    children: [
                      _roiChip('Samples Given', '$_roiSamplesGiven'),
                      _roiChip('Schools Reached', '$_roiSchoolsReached'),
                      _roiChip(
                        'Revenue Earned',
                        'KES ${_roiRevenue.toStringAsFixed(0)}',
                      ),
                      _roiChip(
                        'Won Value',
                        'KES ${_roiWonValue.toStringAsFixed(0)}',
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Widget _roiChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildClientTypeFilter() {
    return ClientTypeFilterBar(
      selected: _selectedClientType,
      onChanged: (value) async {
        setState(() {
          _selectedClientType = value;
          _selectedSchoolId = null;
        });
        await _loadDistributions();
      },
    );
  }

  Widget _buildRequestForm(List<SchoolModel> schools) {
    final selectedSchool =
        schools.where((s) => s.id == _selectedSchoolId).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.playlist_add_check, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Request Book Samples',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            selectedSchool == null
                ? 'Select a client above, then choose books and quantities.'
                : 'Requesting for: ${selectedSchool.name}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _requestSearchController,
            onChanged: (value) => setState(() => _requestSearchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search books...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._samples
              .where((sample) {
                final q = _requestSearchQuery.trim().toLowerCase();
                return q.isEmpty ||
                    sample.name.toLowerCase().contains(q) ||
                    (sample.category).toLowerCase().contains(q);
              })
              .map((sample) {
                final isSelected = _requestSampleIds.contains(sample.id);
                final qty = _requestQty[sample.id] ?? 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primaryGreen
                              : Colors.grey.shade300,
                    ),
                    color:
                        isSelected
                            ? AppColors.primaryGreen.withValues(alpha: 0.06)
                            : null,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (_) => _toggleRequestSample(sample),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sample.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              sample.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed:
                                  () => setState(() {
                                    final cur = _requestQty[sample.id] ?? 1;
                                    if (cur > 1)
                                      _requestQty[sample.id] = cur - 1;
                                  }),
                            ),
                            Text('$qty'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed:
                                  () => setState(() {
                                    _requestQty[sample.id] =
                                        (_requestQty[sample.id] ?? 1) + 1;
                                  }),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
          const SizedBox(height: 12),
          TextField(
            controller: _requestNotesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitSampleRequest,
              icon: const Icon(Icons.send),
              label: const Text('Submit Request'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection({required bool compact}) {
    final balance = _balanceByBook;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sample Balance Tracking',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _balanceSummaryChip(
                'Total Issued',
                '$_totalIssued',
                AppColors.primaryGreen,
              ),
              _balanceSummaryChip(
                'Total Returned',
                '$_totalReturned',
                Colors.orange,
              ),
              _balanceSummaryChip(
                'Total Remaining',
                '$_totalRemaining',
                Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingDistributions)
            const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (balance.isEmpty)
            const Text('No sample records found for the current filter.')
          else ...[
            ...balance.entries.map((entry) {
              final issued = entry.value['issued'] ?? 0;
              final returned = entry.value['returned'] ?? 0;
              final remaining = issued - returned;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Issued: $issued   •   Returned: $returned',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$remaining left',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Request History',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_filteredDistributions.isEmpty)
              const Text('No records.')
            else
              ..._filteredDistributions.map((row) {
                final schoolName =
                    (row['schools'] is Map ? row['schools']['name'] : null)
                        ?.toString() ??
                    'Unknown client';
                final issued = (row['quantity'] as num?)?.toInt() ?? 0;
                final returned = (row['returned_qty'] as num?)?.toInt() ?? 0;
                final remaining = issued - returned;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['sample_name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$schoolName • $issued issued • $returned returned • $remaining left',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _updateReturnedQty(row),
                        child: const Text('Update Returned'),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _balanceSummaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolSelector(List<SchoolModel> schools) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue:
            schools.any((s) => s.id == _selectedSchoolId)
                ? _selectedSchoolId
                : null,
        decoration: InputDecoration(
          labelText: 'Select School',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.school_outlined),
        ),
        items:
            schools
                .map(
                  (school) => DropdownMenuItem<String>(
                    value: school.id,
                    child: Text(
                      '${school.name} • ${school.county} • ${school.bookCategory ?? "No SOP"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
        onChanged: (value) => setState(() => _selectedSchoolId = value),
      ),
    );
  }

  Widget _buildRemainingTracker({required bool compact}) {
    final progress =
        (_remainingSampleTotal + _distributedSampleTotal) == 0
            ? 0.0
            : _distributedSampleTotal /
                (_remainingSampleTotal + _distributedSampleTotal);

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? double.infinity : 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Samples Remaining',
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_remainingSampleTotal left',
                      style: TextStyle(
                        fontSize: compact ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_distributedSampleTotal distributed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tracker updates whenever you give a sample to a school.',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCard(CatalogItemModel sample, List<SchoolModel> schools) {
    final stock = sample.stockQty;
    SchoolModel? selectedSchool;
    for (final school in schools) {
      if (school.id == _selectedSchoolId) {
        selectedSchool = school;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width:
                        isCompact
                            ? constraints.maxWidth
                            : constraints.maxWidth - 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sample.name,
                          style: TextStyle(
                            fontSize: isCompact ? 15 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sample.description ?? '',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedSchool == null
                              ? 'Select a school to see its SOP details.'
                              : '${selectedSchool.bookCategory ?? "No SOP"} • ${selectedSchool.focusAreas.isEmpty ? "General" : selectedSchool.focusAreas.join(", ")}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                        if (selectedSchool?.sampleProofUrl != null &&
                            selectedSchool!.sampleProofUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder:
                                    (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(
                                          selectedSchool?.sampleProofUrl ?? '',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                              );
                            },
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                            ),
                            label: const Text('View Stamped Document'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$stock remaining',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Text(sample.category),
                    ],
                  ),
                  SizedBox(
                    width: isCompact ? constraints.maxWidth : null,
                    child: ElevatedButton.icon(
                      onPressed:
                          selectedSchool == null
                              ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select a school first.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                              : () async => await _assignSample(
                                sample: sample,
                                school: selectedSchool!,
                              ),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Give to School'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Distribution',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_distributionLog.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('No samples have been assigned yet.'),
          )
        else
          ..._distributionLog.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(entry),
            ),
          ),
      ],
    );
  }
}

class SampleProofGalleryPage extends StatefulWidget {
  const SampleProofGalleryPage({super.key});

  @override
  State<SampleProofGalleryPage> createState() => _SampleProofGalleryPageState();
}

class _SampleProofGalleryPageState extends State<SampleProofGalleryPage> {
  final ApiService _api = ApiService();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _receiptRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _proofRows = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _onboardingReceiptProofRows =
      <Map<String, dynamic>>[];
  List<SchoolModel> _localProofSchools = <SchoolModel>[];

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
      await _dbService.syncData();
      final receiptResponse = await _api.getAll('school_sample_distributions', filter: {'stamped_receipt_url': {'neq': null}}, orderBy: 'distributed_at', orderDir: 'DESC', limit: 300);
      final proofResponse = await _api.getAll('schools', filter: {'sample_proof_url': {'neq': null}}, orderBy: 'created_at', orderDir: 'DESC', limit: 300);
      final onboardingReceiptProofResponse = await _api.getAll('school_sample_distributions', filter: {'sample_category': 'Onboarding', 'stamped_receipt_url': {'neq': null}}, orderBy: 'distributed_at', orderDir: 'DESC', limit: 300);
      final schoolRows = await _api.getAll('schools', limit: 500);
      final schoolNames = {for (final row in schoolRows) row['id'].toString(): {'name': row['name'], 'county': row['county']}};
      for (final row in [...receiptResponse, ...onboardingReceiptProofResponse]) {
        row['schools'] = schoolNames[row['school_id']?.toString()];
      }
      if (!mounted) return;
      final localSchools = await _dbService.getAllSchoolProfiles();
      setState(() {
        _receiptRows = List<Map<String, dynamic>>.from(
          receiptResponse.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _proofRows = List<Map<String, dynamic>>.from(
          proofResponse.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _onboardingReceiptProofRows = List<Map<String, dynamic>>.from(
          onboardingReceiptProofResponse.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        _localProofSchools =
            localSchools
                .where(
                  (s) =>
                      (s.sampleProofUrl == null ||
                          s.sampleProofUrl!.trim().isEmpty) &&
                      (s.sampleProofPath != null &&
                          s.sampleProofPath!.trim().isNotEmpty),
                )
                .toList();
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sample Photos'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Onboarding Proofs'),
              Tab(text: 'Stamped Receipts'),
            ],
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
                : TabBarView(
                  children: [
                    _buildOnboardingProofGrid(),
                    _buildStampedReceiptGrid(),
                  ],
                ),
      ),
    );
  }

  Widget _buildOnboardingProofGrid() {
    final fromSchools =
        _proofRows
            .where(
              (row) =>
                  (row['sample_proof_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();
    final fromReceipts =
        _onboardingReceiptProofRows
            .where(
              (row) =>
                  (row['stamped_receipt_url']?.toString().trim().isNotEmpty ??
                      false),
            )
            .toList();

    if (fromSchools.isEmpty &&
        fromReceipts.isEmpty &&
        _localProofSchools.isEmpty) {
      return const Center(child: Text('No onboarding proof photos yet.'));
    }

    final mergedCount =
        fromSchools.length + fromReceipts.length + _localProofSchools.length;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: mergedCount,
      itemBuilder: (context, index) {
        if (index < fromSchools.length) {
          final row = fromSchools[index];
          final url = row['sample_proof_url']?.toString() ?? '';
          final schoolName = row['name']?.toString() ?? 'School';
          final county = row['county']?.toString() ?? '';
          return _buildPhotoCard(
            url: url,
            title: schoolName,
            subtitle:
                county.isEmpty
                    ? 'Onboarding proof'
                    : '$county • Onboarding proof',
            onDelete: () => _deleteSchoolProof(row),
          );
        }

        if (index < fromSchools.length + fromReceipts.length) {
          final row = fromReceipts[index - fromSchools.length];
          final url = row['stamped_receipt_url']?.toString() ?? '';
          final schoolName = row['schools']?['name']?.toString() ?? 'School';
          final county = row['schools']?['county']?.toString() ?? '';
          return _buildPhotoCard(
            url: url,
            title: schoolName,
            subtitle:
                county.isEmpty
                    ? 'Onboarding proof (receipt)'
                    : '$county • Onboarding proof (receipt)',
            onDelete: () => _deleteReceiptProof(row),
          );
        }

        final localSchool =
            _localProofSchools[index -
                fromSchools.length -
                fromReceipts.length];
        final localPath = localSchool.sampleProofPath?.toString() ?? '';
        final county = localSchool.county;
        return _buildPhotoCard(
          url: '',
          localPath: localPath,
          title: localSchool.name,
          subtitle:
              county.isEmpty
                  ? 'Onboarding proof (local unsynced)'
                  : '$county • Onboarding proof (local unsynced)',
          onDelete: () => _deleteLocalSchoolProof(localSchool.id),
        );
      },
    );
  }

  Widget _buildStampedReceiptGrid() {
    if (_receiptRows.isEmpty) {
      return const Center(child: Text('No stamped sample photos yet.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: _receiptRows.length,
      itemBuilder: (context, index) {
        final row = _receiptRows[index];
        final url = row['stamped_receipt_url']?.toString() ?? '';
        final schoolName = row['schools']?['name']?.toString() ?? 'School';
        final sampleName = row['sample_name']?.toString() ?? 'Sample';
        return _buildPhotoCard(
          url: url,
          title: schoolName,
          subtitle: sampleName,
          onDelete: () => _deleteReceiptProof(row),
        );
      },
    );
  }

  Widget _buildPhotoCard({
    required String url,
    String? localPath,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder:
              (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  (localPath != null && localPath.trim().isNotEmpty)
                      ? Image.file(
                        File(localPath),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              alignment: Alignment.center,
                              child: const Text('Could not load'),
                            ),
                      )
                      : Image.network(
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title\n$subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete photo',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLocalSchoolProof(String schoolId) async {
    final approved = await _confirmDelete();
    if (!approved) return;
    try {
      final schools = await _dbService.getAllSchoolProfiles();
      final idx = schools.indexWhere((s) => s.id == schoolId);
      if (idx == -1) return;
      final school = schools[idx];
      final updated = SchoolModel(
        id: school.id,
        name: school.name,
        phone: school.phone,
        county: school.county,
        focusAreas: school.focusAreas,
        bookCategory: school.bookCategory,
        latitude: school.latitude,
        longitude: school.longitude,
        photoUrl: school.photoUrl,
        photoPath: school.photoPath,
        capturedBy: school.capturedBy,
        capturedAt: school.capturedAt,
        captureStatus: school.captureStatus,
        contactName: school.contactName,
        contactPhone: school.contactPhone,
        contactTitle: school.contactTitle,
        feedback: school.feedback,
        notes: school.notes,
        samplesLeft: school.samplesLeft,
        sampleBooks: school.sampleBooks,
        sampleProofUrl: null,
        sampleProofPath: null,
        schoolOwnership: school.schoolOwnership,
        schoolOwnershipOther: school.schoolOwnershipOther,
        schoolPopulation: school.schoolPopulation,
        schoolLifecycleStatus: school.schoolLifecycleStatus,
        engagementType: school.engagementType,
        isSynced: false,
        createdAt: school.createdAt,
        updatedAt: DateTime.now(),
      );
      await _dbService.saveSchoolProfile(updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete local photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSchoolProof(Map<String, dynamic> row) async {
    final schoolId = row['id']?.toString();
    if (schoolId == null || schoolId.isEmpty) return;
    final approved = await _confirmDelete();
    if (!approved) return;

    try {
      await _api.patch('schools', schoolId, {'sample_proof_url': null, 'sample_proof_path': null});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReceiptProof(Map<String, dynamic> row) async {
    final receiptId = row['id']?.toString();
    if (receiptId == null || receiptId.isEmpty) return;
    final approved = await _confirmDelete();
    if (!approved) return;

    try {
      await _api.patch('school_sample_distributions', receiptId, {'stamped_receipt_url': null, 'stamped_receipt_path': null});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmDelete() async {
    final answer = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Photo'),
            content: const Text('Are you sure you want to delete this photo?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    return answer == true;
  }
}
