import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../../models/region_model.dart';
import '../../../models/user_model.dart';

class Role2ManagerDashboardPage extends StatefulWidget {
  const Role2ManagerDashboardPage({super.key});

  @override
  State<Role2ManagerDashboardPage> createState() =>
      _Role2ManagerDashboardPageState();
}

class _Role2ManagerDashboardPageState extends State<Role2ManagerDashboardPage> {
  final DatabaseService _dbService = DatabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<RegionModel> _regions = [];
  List<UserModel> _members = [];
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _allSchools = [];
  List<Map<String, dynamic>> _regionMetrics = [];

  String? _selectedRegion;
  String _searchQuery = '';
  String _dateFilter = 'monthly';
  DateTimeRange? _customDateRange;
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  final int _pageSize = 10;
  String _sortColumn = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final futures = await Future.wait([
        _dbService.getAllRegions(),
        _loadAgents(),
        _loadSchools(),
        _loadAllSales(),
      ]);

      _regions = futures[0] as List<RegionModel>;
      _members = futures[1] as List<UserModel>;
      _allSchools = futures[2] as List<Map<String, dynamic>>;
      final sales = futures[3] as List<Map<String, dynamic>>;

      _buildMetricsInMemory(sales);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      setState(() => _errorMessage = 'Failed to load dashboard data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<List<UserModel>> _loadAgents() async {
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, email, phone, region, sub_region, role')
          .inFilter('role', [2, 4])
          .order('full_name');
      return (data as List)
          .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error loading agents: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadSchools() async {
    try {
      final data = await _supabase
          .from('schools')
          .select(
            'id, name, phone, county, source, contact_name, contact_phone, contact_email, school_lifecycle_status, notes, latitude, longitude, captured_by, created_at',
          )
          .order('name');
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading schools: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadAllSales() async {
    try {
      final data = await _supabase
          .from('school_sales')
          .select('school_id, expected_value, sale_status, created_at')
          .gte('created_at', _getDateFilterStart())
          .lte('created_at', _getDateFilterEnd());
      return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading sales: $e');
      return [];
    }
  }

  void _buildMetricsInMemory(List<Map<String, dynamic>> sales) {
    _regionMetrics = [];

    final memberToRegion = <String, String>{};
    final memberToSubRegion = <String, String>{};
    final memberMap = <String, UserModel>{};

    for (final m in _members) {
      memberMap[m.id] = m;
      if (m.region != null) memberToRegion[m.id] = m.region!;
      if (m.subRegion != null) memberToSubRegion[m.id] = m.subRegion!;
    }

    // Filter schools based on date filter
    final start = DateTime.parse(_getDateFilterStart());
    final end = DateTime.parse(_getDateFilterEnd());
    _schools =
        _allSchools.where((s) {
          final date = _parseDate(s['created_at']);
          if (date == null) return false;
          return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(end.add(const Duration(seconds: 1)));
        }).toList();

    final schoolToRegion = <String, String>{};
    final schoolToSubRegion = <String, String>{};
    for (final s in _allSchools) {
      final capturedBy = s['captured_by'] as String?;
      if (capturedBy != null) {
        if (memberToRegion.containsKey(capturedBy)) {
          schoolToRegion[s['id']] = memberToRegion[capturedBy]!;
        }
        if (memberToSubRegion.containsKey(capturedBy)) {
          schoolToSubRegion[s['id']] = memberToSubRegion[capturedBy]!;
        }
      }
    }

    final now = DateTime.now();

    for (final region in _regions) {
      final regionName = region.region;
      final subRegion = region.subRegion;

      int schoolsCount = 0;
      int visitsCount = 0;

      for (final member in _members) {
        if (member.region == regionName || member.subRegion == subRegion) {
          final memberSchools =
              _schools.where((s) => s['captured_by'] == member.id).length;
          schoolsCount += memberSchools;
          visitsCount += memberSchools * 3;
        }
      }

      double totalSales = 0;
      int wonSales = 0;

      for (final sale in sales) {
        final schoolId = sale['school_id'] as String?;
        if (schoolId != null &&
            (schoolToRegion[schoolId] == regionName ||
                schoolToSubRegion[schoolId] == subRegion)) {
          totalSales += (sale['expected_value'] as num?)?.toDouble() ?? 0;
          if ((sale['sale_status'] as String?)?.toLowerCase() == 'won') {
            wonSales++;
          }
        }
      }

      String inChargeName = 'Unassigned';
      if (region.assignedTo != null && region.assignedTo!.isNotEmpty) {
        if (memberMap.containsKey(region.assignedTo)) {
          inChargeName = memberMap[region.assignedTo]!.fullName ?? 'Unknown';
        }
      }

      final memberCount =
          _members
              .where((m) => m.region == regionName || m.subRegion == subRegion)
              .length;

      final achievement =
          schoolsCount > 0
              ? (visitsCount / (schoolsCount * 10) * 100).clamp(0.0, 100.0)
              : 0.0;

      int currentMonth = 0;
      int prevMonth = 0;

      for (final s in _allSchools) {
        final sid = s['id'] as String?;
        if (sid != null &&
            (schoolToRegion[sid] == regionName ||
                schoolToSubRegion[sid] == subRegion) &&
            s['created_at'] != null) {
          final date = _parseDate(s['created_at']);
          if (date != null) {
            if (date.year == now.year && date.month == now.month) {
              currentMonth++;
            } else if (date.year == now.year && date.month == now.month - 1) {
              prevMonth++;
            } else if (now.month == 1 &&
                date.year == now.year - 1 &&
                date.month == 12) {
              prevMonth++;
            }
          }
        }
      }

      String trend = 'unchanged';
      if (prevMonth == 0 && currentMonth > 0) {
        trend = 'up';
      } else if (currentMonth > prevMonth) {
        trend = 'up';
      } else if (currentMonth < prevMonth) {
        trend = 'down';
      }

      _regionMetrics.add({
        'region': regionName,
        'subRegion': subRegion,
        'inCharge': inChargeName,
        'memberCount': memberCount,
        'schoolsCount': schoolsCount,
        'visitsCount': visitsCount,
        'totalSales': totalSales,
        'wonSales': wonSales,
        'achievement': achievement,
        'trend': trend,
      });
    }
  }

  String _getDateFilterStart() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'daily':
        return DateTime(now.year, now.month, now.day).toIso8601String();
      case 'weekly':
        return DateTime(
          now.year,
          now.month,
          now.day - now.weekday + 1,
        ).toIso8601String();
      case 'monthly':
        return DateTime(now.year, now.month, 1).toIso8601String();
      case 'custom':
        return _customDateRange?.start.toIso8601String() ??
            DateTime(now.year, now.month, 1).toIso8601String();
      default:
        return DateTime(now.year, now.month, 1).toIso8601String();
    }
  }

  String _getDateFilterEnd() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case 'daily':
        return DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
        ).toIso8601String();
      case 'weekly':
        return DateTime(
          now.year,
          now.month,
          now.day - now.weekday + 7,
          23,
          59,
          59,
        ).toIso8601String();
      case 'monthly':
        return DateTime(
          now.year,
          now.month + 1,
          0,
          23,
          59,
          59,
        ).toIso8601String();
      case 'custom':
        return _customDateRange?.end.toIso8601String() ??
            DateTime.now().toIso8601String();
      default:
        return DateTime.now().toIso8601String();
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<Map<String, dynamic>> _getFilteredRegionMetrics() {
    var filtered = _regionMetrics.toList();
    if (_selectedRegion != null && _selectedRegion != 'All') {
      filtered = filtered.where((r) => r['region'] == _selectedRegion).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final sq = _searchQuery.toLowerCase();
      filtered =
          filtered
              .where(
                (r) =>
                    (r['region'] as String).toLowerCase().contains(sq) ||
                    (r['inCharge'] as String).toLowerCase().contains(sq),
              )
              .toList();
    }
    return filtered;
  }

  List<UserModel> _getFilteredMembers() {
    var filtered = _members.toList();
    if (_selectedRegion != null && _selectedRegion != 'All') {
      filtered = filtered.where((m) => m.region == _selectedRegion).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final sq = _searchQuery.toLowerCase();
      filtered =
          filtered
              .where(
                (m) =>
                    (m.fullName ?? '').toLowerCase().contains(sq) ||
                    (m.email).toLowerCase().contains(sq),
              )
              .toList();
    }
    return filtered;
  }

  List<Map<String, dynamic>> _getFilteredSchools() {
    var filtered = _schools.toList();
    if (_selectedRegion != null && _selectedRegion != 'All') {
      filtered =
          filtered.where((s) {
            final capturedBy = s['captured_by'] as String?;
            final member = _members.firstWhere(
              (m) => m.id == capturedBy,
              orElse: () => UserModel(id: '', email: ''),
            );
            return member.region == _selectedRegion;
          }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final sq = _searchQuery.toLowerCase();
      filtered =
          filtered
              .where(
                (s) =>
                    (s['name'] as String? ?? '').toLowerCase().contains(sq) ||
                    (s['phone'] as String? ?? '').toLowerCase().contains(sq) ||
                    (s['county'] as String? ?? '').toLowerCase().contains(sq),
              )
              .toList();
    }
    return filtered;
  }

  List<Map<String, dynamic>> _getSortedSchools() {
    final schools = _getFilteredSchools();
    schools.sort((a, b) {
      final valA = _getSchoolSortValue(a, _sortColumn);
      final valB = _getSchoolSortValue(b, _sortColumn);
      final cmp = valA.compareTo(valB);
      return _sortAscending ? cmp : -cmp;
    });
    return schools;
  }

  dynamic _getSchoolSortValue(Map<String, dynamic> school, String column) {
    switch (column) {
      case 'name':
        return school['name'] ?? '';
      case 'county':
        return school['county'] ?? '';
      case 'status':
        return school['school_lifecycle_status'] ?? '';
      case 'created':
        return school['created_at'] ?? '';
      default:
        return school['name'] ?? '';
    }
  }

  void _sortSchools(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    setState(() {});
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() {
        _customDateRange = range;
        _dateFilter = 'custom';
      });
      _loadDashboard();
    }
  }

  void _exportData() {
    final schools = _getSortedSchools();
    final csv = StringBuffer();
    csv.writeln(
      'School Name,Phone,County,Source,Contact Name,Contact Phone,Contact Email,Status,Notes',
    );
    for (final s in schools) {
      csv.writeln(
        '${s['name'] ?? ''},${s['phone'] ?? ''},${s['county'] ?? ''},${s['source'] ?? ''},${s['contact_name'] ?? ''},${s['contact_phone'] ?? ''},${s['contact_email'] ?? ''},${s['school_lifecycle_status'] ?? ''},${s['notes'] ?? ''}',
      );
    }
    Clipboard.setData(ClipboardData(text: csv.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'CSV data copied to clipboard',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Insights & Analytics',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: _loadDashboard,
            tooltip: 'Refresh Data',
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter by Date',
            onSelected: (value) {
              if (value == 'custom') {
                _pickDateRange();
              } else {
                setState(() => _dateFilter = value);
                _loadDashboard();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'daily', child: Text('Daily')),
                  const PopupMenuItem(value: 'weekly', child: Text('Weekly')),
                  const PopupMenuItem(value: 'monthly', child: Text('Monthly')),
                  const PopupMenuItem(
                    value: 'custom',
                    child: Text('Custom Range'),
                  ),
                ],
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateFilter == 'custom' && _customDateRange != null
                        ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                        : _dateFilter.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : _errorMessage.isNotEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Oops! Something went wrong:\n$_errorMessage',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                        onPressed: _loadDashboard,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
              : RefreshIndicator(
                color: AppColors.primaryGreen,
                onRefresh: _loadDashboard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 24),
                      _buildSummaryCards(),
                      const SizedBox(height: 28),
                      _buildRegionalOverview(),
                      const SizedBox(height: 28),
                      _buildPerformanceChart(),
                      const SizedBox(height: 28),
                      _buildMembersSection(),
                      const SizedBox(height: 28),
                      _buildSchoolsSection(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manager Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Overview of regional performance, members, and school onboarding',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final totalRegions = _regions.length;
    final totalMembers = _members.length;
    final totalSchools = _allSchools.length;

    String bestRegion = 'N/A';
    String worstRegion = 'N/A';
    double overallAchievement = 0.0;

    if (_regionMetrics.isNotEmpty) {
      bestRegion =
          _regionMetrics.reduce(
                (a, b) =>
                    (a['achievement'] as double) > (b['achievement'] as double)
                        ? a
                        : b,
              )['region']
              as String;
      worstRegion =
          _regionMetrics.reduce(
                (a, b) =>
                    (a['achievement'] as double) < (b['achievement'] as double)
                        ? a
                        : b,
              )['region']
              as String;
      overallAchievement =
          _regionMetrics.fold<double>(
            0,
            (sum, m) => sum + (m['achievement'] as double),
          ) /
          _regionMetrics.length;
    }

    final schoolsAdded = _schools.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth > 800
                ? 4
                : constraints.maxWidth > 500
                ? 2
                : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: constraints.maxWidth > 500 ? 2.5 : 1.5,
          children: [
            _buildStatCard(
              'Total Regions',
              '$totalRegions',
              Icons.map_outlined,
              Colors.blue,
            ),
            _buildStatCard(
              'Total Members',
              '$totalMembers',
              Icons.people_outline,
              Colors.orange,
            ),
            _buildStatCard(
              'Total Schools',
              '$totalSchools',
              Icons.school_outlined,
              Colors.purple,
            ),
            _buildStatCard(
              'New (Period)',
              '+$schoolsAdded',
              Icons.trending_up,
              Colors.green,
            ),
            _buildStatCard(
              'Best Region',
              bestRegion,
              Icons.emoji_events_outlined,
              Colors.amber,
            ),
            _buildStatCard(
              'Needs Attention',
              worstRegion,
              Icons.warning_amber_outlined,
              Colors.red,
            ),
            _buildStatCard(
              'Avg Achievement',
              '${overallAchievement.toStringAsFixed(1)}%',
              Icons.pie_chart_outline,
              Colors.teal,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionalOverview() {
    final filtered = _getFilteredRegionMetrics();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Regional Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search regions...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No regions found matching your search.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final metric = filtered[index];
                final achievement = metric['achievement'] as double;
                final trend = metric['trend'] as String;
                final trendIcon =
                    trend == 'up'
                        ? Icons.arrow_upward
                        : trend == 'down'
                        ? Icons.arrow_downward
                        : Icons.horizontal_rule;
                final trendColor =
                    trend == 'up'
                        ? Colors.green
                        : trend == 'down'
                        ? Colors.red
                        : Colors.grey;

                return InkWell(
                  onTap: () => _showRegionDetail(metric),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                achievement >= 70
                                    ? Colors.green.withOpacity(0.1)
                                    : achievement >= 40
                                    ? Colors.amber.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${achievement.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  achievement >= 70
                                      ? Colors.green
                                      : achievement >= 40
                                      ? Colors.amber.shade800
                                      : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric['region'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'In-Charge: ${metric['inCharge']} • ${metric['memberCount']} Members',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${metric['schoolsCount']} Schools',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(trendIcon, color: trendColor, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  trend == 'up'
                                      ? 'Trending Up'
                                      : trend == 'down'
                                      ? 'Trending Down'
                                      : 'Stable',
                                  style: TextStyle(
                                    color: trendColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showRegionDetail(Map<String, dynamic> metric) {
    final regionName = metric['region'] as String;
    final subRegion = metric['subRegion'] as String;

    final memberToRegion = <String, String>{};
    for (final m in _members) {
      if (m.region != null) memberToRegion[m.id] = m.region!;
    }

    final regionSchools =
        _schools.where((s) {
          final capturedBy = s['captured_by'] as String?;
          return capturedBy != null && memberToRegion[capturedBy] == regionName;
        }).toList();

    final regionMembers =
        _members
            .where((m) => m.region == regionName || m.subRegion == subRegion)
            .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Region: $regionName',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subRegion.isNotEmpty)
                            Text(
                              'Sub-Region: $subRegion',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Achieved: ${metric['achievement'].toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildMiniStat(
                      'In-Charge',
                      metric['inCharge'],
                      Icons.person,
                    ),
                    _buildMiniStat(
                      'Members',
                      '${metric['memberCount']}',
                      Icons.group,
                    ),
                    _buildMiniStat(
                      'Schools',
                      '${metric['schoolsCount']}',
                      Icons.school,
                    ),
                    _buildMiniStat(
                      'Total Sales',
                      '\$${(metric['totalSales'] as double).toStringAsFixed(0)}',
                      Icons.attach_money,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Assigned Members',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: regionMembers.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final member = regionMembers[index];
                      final memberSchools =
                          regionSchools
                              .where((s) => s['captured_by'] == member.id)
                              .toList();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            member.fullName?.substring(0, 1).toUpperCase() ??
                                'U',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                        title: Text(
                          member.fullName ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${member.email ?? ''}\n${member.phone ?? ''}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${memberSchools.length} Schools',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.pop(context);
                          _showMemberDetail(member, memberSchools);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (_regionMetrics.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Regional Visits Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    _regionMetrics
                        .fold<double>(
                          0,
                          (max, m) =>
                              (m['visitsCount'] as int) > max
                                  ? (m['visitsCount'] as int).toDouble()
                                  : max,
                        )
                        .clamp(1, double.infinity) *
                    1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_regionMetrics[group.x.toInt()]['region']}\n${rod.toY.toInt()} Visits',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _regionMetrics.length) {
                          final region =
                              _regionMetrics[idx]['region'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              region.length > 8
                                  ? '${region.substring(0, 6)}...'
                                  : region,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget:
                          (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                barGroups:
                    _regionMetrics.asMap().entries.map((entry) {
                      final metric = entry.value;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: (metric['visitsCount'] as int).toDouble(),
                            color: AppColors.primaryGreen,
                            width: 24,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY:
                                  _regionMetrics
                                      .fold<double>(
                                        0,
                                        (max, m) =>
                                            (m['visitsCount'] as int) > max
                                                ? (m['visitsCount'] as int)
                                                    .toDouble()
                                                : max,
                                      )
                                      .clamp(1, double.infinity) *
                                  1.2,
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    final filtered = _getFilteredMembers();
    final sorted = List<UserModel>.from(filtered);
    sorted.sort((a, b) {
      final valA = _getMemberSortValue(a, _sortColumn);
      final valB = _getMemberSortValue(b, _sortColumn);
      final cmp = valA.compareTo(valB);
      return _sortAscending ? cmp : -cmp;
    });
    final paged =
        sorted.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_selectedRegion != null && _selectedRegion != 'All')
                TextButton.icon(
                  onPressed: () => setState(() => _selectedRegion = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Filter'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  decoration: InputDecoration(
                    labelText: 'Filter by Region',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items:
                      ['All', ..._regions.map((r) => r.region)]
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedRegion = v;
                      _currentPage = 1;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (paged.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No members found in this region.'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
                dataRowMinHeight: 60,
                dataRowMaxHeight: 60,
                columns: const [
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Region')),
                  DataColumn(label: Text('Schools Onboarded')),
                  DataColumn(label: Text('')),
                ],
                rows:
                    paged.map((m) {
                      final memberSchools =
                          _schools
                              .where((s) => s['captured_by'] == m.id)
                              .toList();
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade50,
                                  child: Text(
                                    m.fullName?.substring(0, 1).toUpperCase() ??
                                        'U',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  m.fullName ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.email,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (m.phone != null && m.phone!.isNotEmpty)
                                  Text(
                                    m.phone!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                m.region ?? 'Unassigned',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          DataCell(
                            Center(
                              child: Text(
                                '${memberSchools.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            TextButton(
                              onPressed:
                                  () => _showMemberDetail(m, memberSchools),
                              child: const Text('View Profile'),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          if (sorted.length > _pageSize) _buildPagination(sorted.length),
        ],
      ),
    );
  }

  String _getMemberSortValue(UserModel m, String column) {
    switch (column) {
      case 'name':
        return m.fullName ?? '';
      case 'email':
        return m.email;
      case 'region':
        return m.region ?? '';
      default:
        return m.fullName ?? '';
    }
  }

  void _showMemberDetail(
    UserModel member,
    List<Map<String, dynamic>> memberSchools,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        member.fullName?.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${member.email} • ${member.phone ?? 'No Phone'}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _buildMiniStat(
                        'Region',
                        member.region ?? 'N/A',
                        Icons.map,
                      ),
                      _buildMiniStat(
                        'Sub-Region',
                        member.subRegion ?? 'N/A',
                        Icons.my_location,
                      ),
                      _buildMiniStat(
                        'Total Schools',
                        '${memberSchools.length}',
                        Icons.school,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Onboarded Schools (${memberSchools.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (memberSchools.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'This member has not onboarded any schools yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: memberSchools.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final school = memberSchools[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.school,
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            school['name'] ?? 'Unknown School',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${school['county'] ?? 'No County'} • ${_parseDate(school['created_at'])?.toString().substring(0, 10) ?? 'Unknown Date'}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              school['school_lifecycle_status'] ?? 'N/A',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showSchoolDetail(school);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildSchoolsSection() {
    final sorted = _getSortedSchools();
    final paged =
        sorted.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Schools Directory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                  foregroundColor: AppColors.primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export Data'),
                onPressed: _exportData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search schools by name, phone, or county...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 20),
          if (paged.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No schools found.'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex:
                    _sortColumn == 'name'
                        ? 0
                        : _sortColumn == 'county'
                        ? 1
                        : _sortColumn == 'status'
                        ? 3
                        : _sortColumn == 'created'
                        ? 4
                        : null,
                sortAscending: _sortAscending,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
                dataRowMinHeight: 60,
                dataRowMaxHeight: 60,
                columns: [
                  DataColumn(
                    label: const Text('School Name'),
                    onSort: (_, __) => _sortSchools('name'),
                  ),
                  DataColumn(
                    label: const Text('County'),
                    onSort: (_, __) => _sortSchools('county'),
                  ),
                  DataColumn(label: const Text('Source')),
                  DataColumn(
                    label: const Text('Status'),
                    onSort: (_, __) => _sortSchools('status'),
                  ),
                  DataColumn(
                    label: const Text('Date Onboarded'),
                    onSort: (_, __) => _sortSchools('created'),
                  ),
                ],
                rows:
                    paged.map((s) {
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () => _showSchoolDetail(s),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.school,
                                      color: Colors.purple,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    s['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              s['county'] ?? '-',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                s['source'] ?? '-',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(
                            _buildStatusBadge(
                              s['school_lifecycle_status'] ?? 'Pending',
                            ),
                          ),
                          DataCell(
                            Text(
                              _parseDate(
                                    s['created_at'],
                                  )?.toString().substring(0, 10) ??
                                  '-',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          if (sorted.length > _pageSize) _buildPagination(sorted.length),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.grey.shade800;

    if (status.toLowerCase().contains('active') ||
        status.toLowerCase().contains('won')) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
    } else if (status.toLowerCase().contains('pending')) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
    } else if (status.toLowerCase().contains('inactive') ||
        status.toLowerCase().contains('lost')) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = (totalItems / _pageSize).ceil();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            color: AppColors.primaryGreen,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page $_currentPage of $totalPages',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
            color: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  void _showSchoolDetail(Map<String, dynamic> school) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.school,
                                color: AppColors.primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    school['name'] ?? 'School Profile',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    school['county'] ?? 'Unknown County',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'School Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _detailRow(
                                  'Status',
                                  _buildStatusBadge(
                                    school['school_lifecycle_status'] ?? 'N/A',
                                  ),
                                ),
                                const Divider(height: 24),
                                _detailRow(
                                  'Date Onboarded',
                                  Text(
                                    _parseDate(
                                          school['created_at'],
                                        )?.toString().substring(0, 10) ??
                                        'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                _detailRow(
                                  'Source',
                                  Text(
                                    school['source'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Contact Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _detailRow(
                                  'School Phone',
                                  Text(
                                    school['phone'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                _detailRow(
                                  'Contact Person',
                                  Text(
                                    school['contact_name'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                _detailRow(
                                  'Contact Phone',
                                  Text(
                                    school['contact_phone'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                _detailRow(
                                  'Contact Email',
                                  Text(
                                    school['contact_email'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Additional Information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                _detailRow(
                                  'GPS Location',
                                  Text(
                                    school['latitude'] != null &&
                                            school['longitude'] != null
                                        ? '${school['latitude']}, ${school['longitude']}'
                                        : 'Not Available',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Divider(height: 24),
                                _detailRow(
                                  'Notes',
                                  Text(
                                    school['notes'] ?? 'No notes available.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _detailRow(String label, Widget child) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
