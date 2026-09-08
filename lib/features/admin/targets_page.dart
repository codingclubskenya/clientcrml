import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../models/target_model.dart';
import '../../models/region_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

class TargetsPage extends StatefulWidget {
  const TargetsPage({super.key});

  @override
  State<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends State<TargetsPage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String _selectedScope = 'regional';
  String? _selectedRegionId;
  String? _selectedSubRegion;
  String? _selectedAssigneeId;
  late TabController _tabController;
  List<RegionModel> _regions = [];
  List<UserModel> _agents = [];
  List<UserModel> _businessAdvisors = [];
  List<UserModel> _salesReps = [];
  List<TargetModel> _targets = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final regions = await _dbService.getAllRegions();
      final users = await _dbService.getAllUsers();
      final agents = users.where((u) => u.role == 4).toList();
      final businessAdvisors = users.where((u) => u.role == 3).toList();
      final salesReps = users.where((u) => u.role == 5).toList();
      final targets = await _loadTargets();

      if (!mounted) return;
      setState(() {
        _regions = regions;
        _agents = agents;
        _businessAdvisors = businessAdvisors;
        _salesReps = salesReps;
        _targets = targets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading targets: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<TargetModel>> _loadTargets() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return <TargetModel>[];

    try {
      final data = await Supabase.instance.client
          .from('targets')
          .select()
          .or('assigned_to.eq.${currentUser.id},assigned_to.is.null')
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) => TargetModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error loading targets: $e');
      return <TargetModel>[];
    }
  }

  Future<void> _saveTarget(TargetModel target) async {
    try {
      if (target.id.isEmpty) {
        await Supabase.instance.client.from('targets').insert(target.toMap());
      } else {
        await Supabase.instance.client
            .from('targets')
            .update(target.copyWith(updatedAt: DateTime.now()).toMap())
            .eq('id', target.id);
      }
      await _loadInitialData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving target: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAllTargets() async {
    setState(() => _isSaving = true);
    try {
      final currentTargets = _getCurrentPageTargets();
      for (final target in currentTargets) {
        if (target.id.isEmpty) {
          await Supabase.instance.client.from('targets').insert(target.toMap());
        } else {
          await Supabase.instance.client
              .from('targets')
              .update(target.copyWith(updatedAt: DateTime.now()).toMap())
              .eq('id', target.id);
        }
      }
      await _loadInitialData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Targets saved'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving targets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<TargetModel> _getCurrentPageTargets() {
    final tabIndex = _tabController.index;
    final List<TargetModel> result = [];

    switch (tabIndex) {
      case 0:
        for (final period in ['daily', 'weekly', 'monthly', 'ytd']) {
          for (final product in ['Exercise Books', 'Pens', 'Rulers']) {
            final existing = _getExistingTarget('product_sales', period);
            final key = product.toLowerCase().replaceAll(' ', '_');
            final value = existing?.targetData[key];
            if (value != null) {
              result.add(
                TargetModel(
                  id: existing?.id ?? '',
                  scope: _selectedScope,
                  regionId: _selectedRegionId,
                  subRegion: _selectedSubRegion,
                  assignedTo: _selectedAssigneeId,
                  targetType: 'product_sales',
                  targetPeriod: period,
                  targetData: {...(existing?.targetData ?? {})},
                ),
              );
            }
          }
        }
        break;
      case 1:
        for (final period in ['daily', 'weekly', 'monthly']) {
          final existing = _getExistingTarget('customer_visits', period);
          if (existing != null && existing.targetData.isNotEmpty) {
            result.add(
              TargetModel(
                id: existing.id,
                scope: _selectedScope,
                regionId: _selectedRegionId,
                subRegion: _selectedSubRegion,
                assignedTo: _selectedAssigneeId,
                targetType: 'customer_visits',
                targetPeriod: period,
                targetData: {...existing.targetData},
              ),
            );
          }
        }
        break;
      case 2:
        for (final period in ['daily', 'weekly', 'monthly']) {
          final existing = _getExistingTarget('collections', period);
          if (existing != null && existing.targetData['amount'] != null) {
            result.add(
              TargetModel(
                id: existing.id,
                scope: _selectedScope,
                regionId: _selectedRegionId,
                subRegion: _selectedSubRegion,
                assignedTo: _selectedAssigneeId,
                targetType: 'collections',
                targetPeriod: period,
                targetData: {...existing.targetData},
              ),
            );
          }
        }
        break;
      case 3:
        for (final period in ['daily', 'weekly', 'monthly']) {
          final existing = _getExistingTarget('new_customers', period);
          if (existing != null && existing.targetData['count'] != null) {
            result.add(
              TargetModel(
                id: existing.id,
                scope: _selectedScope,
                regionId: _selectedRegionId,
                subRegion: _selectedSubRegion,
                assignedTo: _selectedAssigneeId,
                targetType: 'new_customers',
                targetPeriod: period,
                targetData: {...existing.targetData},
              ),
            );
          }
        }
        break;
      case 4:
        for (final period in ['weekly', 'monthly']) {
          final existing = _getExistingTarget('sample_distribution', period);
          if (existing != null && existing.targetData.isNotEmpty) {
            result.add(
              TargetModel(
                id: existing.id,
                scope: _selectedScope,
                regionId: _selectedRegionId,
                subRegion: _selectedSubRegion,
                assignedTo: _selectedAssigneeId,
                targetType: 'sample_distribution',
                targetPeriod: period,
                targetData: {...existing.targetData},
              ),
            );
          }
        }
        break;
      case 5:
        final existing = _getExistingTarget('consignment', 'custom');
        if (existing != null && existing.targetData.isNotEmpty) {
          result.add(
            TargetModel(
              id: existing.id,
              scope: _selectedScope,
              regionId: _selectedRegionId,
              subRegion: _selectedSubRegion,
              assignedTo: _selectedAssigneeId,
              targetType: 'consignment',
              targetPeriod: 'custom',
              targetData: {...existing.targetData},
            ),
          );
        }
        break;
    }
    return result;
  }

  TargetModel? _getExistingTarget(String targetType, String targetPeriod) {
    try {
      return _targets.firstWhere(
        (t) =>
            t.targetType == targetType &&
            t.targetPeriod == targetPeriod &&
            t.scope == _selectedScope &&
            (_selectedScope == 'regional'
                ? t.regionId == _selectedRegionId &&
                    t.subRegion == _selectedSubRegion
                : t.assignedTo == _selectedAssigneeId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Targets'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildFilterCard(),
                  _buildTargetTabs(),
                  Expanded(child: _buildTabBarView()),
                  _buildSaveBar(),
                ],
              ),
    );
  }

  Widget _buildFilterCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final crossAxis =
            isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center;
        final rowSpacing = isCompact ? 0.0 : 12.0;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 12,
            vertical: isCompact ? 8 : 12,
          ),
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: crossAxis,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: isCompact ? 18 : 20,
                    color: AppColors.primaryDark,
                  ),
                  SizedBox(width: isCompact ? 6 : 8),
                  Flexible(
                    child: Text(
                      'Configure Targets',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isCompact ? 14 : 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isCompact) ...[
                    const Spacer(),
                    if (_selectedScope == 'regional')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedSubRegion ?? 'Select region',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (_selectedAssigneeId != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedScope == 'agent'
                              ? 'Agent'
                              : _selectedScope == 'business_advisor'
                              ? 'Business Advisor'
                              : 'Sales Rep',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              SizedBox(height: isCompact ? 10 : 12),
              if (isCompact)
                Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedScope,
                      decoration: const InputDecoration(
                        labelText: 'Scope',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'regional',
                          child: Text('Regional'),
                        ),
                        DropdownMenuItem(value: 'agent', child: Text('Agent')),
                        DropdownMenuItem(
                          value: 'business_advisor',
                          child: Text('Business Advisor'),
                        ),
                        DropdownMenuItem(
                          value: 'sales_rep',
                          child: Text('Sales Rep'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedScope = value;
                          _selectedRegionId = null;
                          _selectedSubRegion = null;
                          _selectedAssigneeId = null;
                        });
                      },
                    ),
                    SizedBox(height: isCompact ? 8 : 12),
                    if (_selectedScope == 'regional')
                      DropdownButtonFormField<String>(
                        value: _selectedRegionId,
                        decoration: const InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items:
                            _regions
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text(r.region),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRegionId = value;
                            _selectedSubRegion = null;
                          });
                        },
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedAssigneeId,
                        decoration: InputDecoration(
                          labelText:
                              _selectedScope == 'agent'
                                  ? 'Agent'
                                  : _selectedScope == 'business_advisor'
                                  ? 'Business Advisor'
                                  : 'Sales Rep',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Select...'),
                          ),
                          ...(_selectedScope == 'agent'
                                  ? _agents
                                  : _selectedScope == 'business_advisor'
                                  ? _businessAdvisors
                                  : _salesReps)
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(u.fullName ?? u.email),
                                ),
                              ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => _selectedAssigneeId = value),
                      ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedScope,
                        decoration: const InputDecoration(
                          labelText: 'Scope',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'regional',
                            child: Text('Regional'),
                          ),
                          DropdownMenuItem(
                            value: 'agent',
                            child: Text('Agent'),
                          ),
                          DropdownMenuItem(
                            value: 'business_advisor',
                            child: Text('Business Advisor'),
                          ),
                          DropdownMenuItem(
                            value: 'sales_rep',
                            child: Text('Sales Rep'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedScope = value;
                            _selectedRegionId = null;
                            _selectedSubRegion = null;
                            _selectedAssigneeId = null;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: rowSpacing),
                    if (_selectedScope == 'regional')
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedRegionId,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items:
                              _regions
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r.id,
                                      child: Text(r.region),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRegionId = value;
                              _selectedSubRegion = null;
                            });
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedAssigneeId,
                          decoration: InputDecoration(
                            labelText:
                                _selectedScope == 'agent'
                                    ? 'Agent'
                                    : _selectedScope == 'business_advisor'
                                    ? 'Business Advisor'
                                    : 'Sales Rep',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Select...'),
                            ),
                            ...(_selectedScope == 'agent'
                                    ? _agents
                                    : _selectedScope == 'business_advisor'
                                    ? _businessAdvisors
                                    : _salesReps)
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text(u.fullName ?? u.email),
                                  ),
                                ),
                          ],
                          onChanged:
                              (value) =>
                                  setState(() => _selectedAssigneeId = value),
                        ),
                      ),
                  ],
                ),
              if (_selectedScope == 'regional' &&
                  _selectedRegionId != null) ...[
                SizedBox(height: isCompact ? 10 : 12),
                DropdownButtonFormField<String>(
                  value: _selectedSubRegion,
                  decoration: InputDecoration(
                    labelText: 'Sub Region',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 10 : 12,
                      vertical: isCompact ? 10 : 12,
                    ),
                  ),
                  items:
                      _regions
                          .where(
                            (r) =>
                                r.id == _selectedRegionId &&
                                r.subRegion.trim().isNotEmpty,
                          )
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.subRegion.trim(),
                              child: Text(r.subRegion.trim()),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) => setState(() => _selectedSubRegion = value),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetTabs() {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorColor: AppColors.primaryGreen,
        indicator: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
        ),
        labelPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 10 : 12,
        ),
        tabs: const [
          Tab(text: 'Products'),
          Tab(text: 'Visits'),
          Tab(text: 'Collections'),
          Tab(text: 'Customers'),
          Tab(text: 'Samples'),
          Tab(text: 'Consignments'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildProductTargets(),
        _buildCustomerVisitTargets(),
        _buildCollectionTargets(),
        _buildNewCustomerTargets(),
        _buildSampleDistributionTargets(),
        _buildConsignmentTargets(),
      ],
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: EdgeInsets.all(
        MediaQuery.of(context).size.width < 600 ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveAllTargets,
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Saving...' : 'Save All Targets'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.width < 600 ? 12 : 14,
              ),
              textStyle: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16,
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.primaryGreen.withValues(alpha: 0.85);
                }
                return null;
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductTargets() {
    final products = ['Exercise Books', 'Pens', 'Rulers'];
    final periods = ['daily', 'weekly', 'monthly', 'ytd'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Product Sales Targets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...products.map((product) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          periods.map((period) {
                            final existing = _getExistingTarget(
                              'product_sales',
                              period,
                            );
                            final currentValue =
                                existing
                                    ?.targetData[product
                                        .toLowerCase()
                                        .replaceAll(' ', '_')]
                                    ?.toString() ??
                                '';
                            return Container(
                              width: 110,
                              margin: EdgeInsets.only(
                                right: period != 'ytd' ? 8 : 0,
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: period.toUpperCase(),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: currentValue,
                                  )
                                  ..selection = TextSelection.fromPosition(
                                    TextPosition(offset: currentValue.length),
                                  ),
                                onChanged: (value) {
                                  final target = TargetModel(
                                    scope: _selectedScope,
                                    regionId: _selectedRegionId,
                                    subRegion: _selectedSubRegion,
                                    assignedTo: _selectedAssigneeId,
                                    targetType: 'product_sales',
                                    targetPeriod: period,
                                    targetData: {
                                      ...(existing?.targetData ?? {}),
                                      product
                                          .toLowerCase()
                                          .replaceAll(' ', '_'): value.isEmpty
                                              ? null
                                              : int.tryParse(value),
                                    },
                                  );
                                  _saveTarget(target);
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCustomerVisitTargets() {
    final customerTypes = ['Schools', 'Institutions', 'Bookshops'];
    final periods = ['daily', 'weekly', 'monthly'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Customer Visit Targets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...customerTypes.map((type) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          periods.map((period) {
                            final existing = _getExistingTarget(
                              'customer_visits',
                              period,
                            );
                            final key = type.toLowerCase();
                            final currentValue =
                                existing?.targetData[key]?.toString() ?? '';
                            return Container(
                              width: 110,
                              margin: EdgeInsets.only(
                                right: period != 'monthly' ? 8 : 0,
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: period.toUpperCase(),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: currentValue,
                                  )
                                  ..selection = TextSelection.fromPosition(
                                    TextPosition(offset: currentValue.length),
                                  ),
                                onChanged: (value) {
                                  final target = TargetModel(
                                    scope: _selectedScope,
                                    regionId: _selectedRegionId,
                                    subRegion: _selectedSubRegion,
                                    assignedTo: _selectedAssigneeId,
                                    targetType: 'customer_visits',
                                    targetPeriod: period,
                                    targetData: {
                                      ...(existing?.targetData ?? {}),
                                      key:
                                          value.isEmpty
                                              ? null
                                              : int.tryParse(value),
                                    },
                                  );
                                  _saveTarget(target);
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCollectionTargets() {
    final periods = ['daily', 'weekly', 'monthly'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Collection Targets (KES)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...periods.map((period) {
          final existing = _getExistingTarget('collections', period);
          final currentValue = existing?.targetData['amount']?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  labelText: '${period.toUpperCase()} Target (KES)',
                  border: const OutlineInputBorder(),
                  prefixText: 'KES ',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: currentValue)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: currentValue.length),
                  ),
                onChanged: (value) {
                  final target = TargetModel(
                    scope: _selectedScope,
                    regionId: _selectedRegionId,
                    subRegion: _selectedSubRegion,
                    assignedTo: _selectedAssigneeId,
                    targetType: 'collections',
                    targetPeriod: period,
                    targetData: {
                      ...(existing?.targetData ?? {}),
                      'amount': value.isEmpty ? null : int.tryParse(value),
                    },
                  );
                  _saveTarget(target);
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNewCustomerTargets() {
    final periods = ['daily', 'weekly', 'monthly'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'New Customer Targets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...periods.map((period) {
          final existing = _getExistingTarget('new_customers', period);
          final currentValue = existing?.targetData['count']?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  labelText: '${period.toUpperCase()} Target (customers)',
                  border: const OutlineInputBorder(),
                  suffixText: 'customers',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: currentValue)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: currentValue.length),
                  ),
                onChanged: (value) {
                  final target = TargetModel(
                    scope: _selectedScope,
                    regionId: _selectedRegionId,
                    subRegion: _selectedSubRegion,
                    assignedTo: _selectedAssigneeId,
                    targetType: 'new_customers',
                    targetPeriod: period,
                    targetData: {
                      ...(existing?.targetData ?? {}),
                      'count': value.isEmpty ? null : int.tryParse(value),
                    },
                  );
                  _saveTarget(target);
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSampleDistributionTargets() {
    final items = ['Exercise Book Samples', 'Pen Samples'];
    final periods = ['weekly', 'monthly'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Sample Distribution Targets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          periods.map((period) {
                            final existing = _getExistingTarget(
                              'sample_distribution',
                              period,
                            );
                            final key = item.toLowerCase().replaceAll(' ', '_');
                            final currentValue =
                                existing?.targetData[key]?.toString() ?? '';
                            return Container(
                              width: 140,
                              margin: EdgeInsets.only(
                                right: period != 'monthly' ? 8 : 0,
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: period.toUpperCase(),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: currentValue,
                                  )
                                  ..selection = TextSelection.fromPosition(
                                    TextPosition(offset: currentValue.length),
                                  ),
                                onChanged: (value) {
                                  final target = TargetModel(
                                    scope: _selectedScope,
                                    regionId: _selectedRegionId,
                                    subRegion: _selectedSubRegion,
                                    assignedTo: _selectedAssigneeId,
                                    targetType: 'sample_distribution',
                                    targetPeriod: period,
                                    targetData: {
                                      ...(existing?.targetData ?? {}),
                                      key:
                                          value.isEmpty
                                              ? null
                                              : int.tryParse(value),
                                    },
                                  );
                                  _saveTarget(target);
                                },
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConsignmentTargets() {
    final fields = [
      {'key': 'max_active_consignments', 'label': 'Max Active Consignments'},
      {'key': 'max_overdue_consignments', 'label': 'Max Overdue Consignments'},
      {'key': 'max_consignment_value', 'label': 'Max Consignment Value (KES)'},
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Consignment Targets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...fields.map((field) {
          final existing = _getExistingTarget('consignment', 'custom');
          final currentValue =
              existing?.targetData[field['key']]?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  labelText: field['label'] as String,
                  border: const OutlineInputBorder(),
                  suffixText:
                      field['key'] == 'max_consignment_value' ? 'KES' : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
                controller: TextEditingController(text: currentValue)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: currentValue.length),
                  ),
                onChanged: (value) {
                  final target = TargetModel(
                    scope: _selectedScope,
                    regionId: _selectedRegionId,
                    subRegion: _selectedSubRegion,
                    assignedTo: _selectedAssigneeId,
                    targetType: 'consignment',
                    targetPeriod: 'custom',
                    targetData: {
                      ...(existing?.targetData ?? {}),
                      field['key'] as String:
                          value.isEmpty ? null : int.tryParse(value),
                    },
                  );
                  _saveTarget(target);
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
