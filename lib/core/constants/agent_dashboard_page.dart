import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // NEW DEPENDENCY — see note at bottom of file

import '../../core/constants/agent_screens.dart';
import '../../core/constants/colors.dart';
import '../../core/daily_shift.dart';
import '../../features/admin/regions_management_page.dart';
import '../../features/admin/target_performance_page.dart';
import '../../features/admin/team_attendance_page.dart';
import '../../features/admin/user_school_onboarding_page.dart';
import '../../features/admin/users_list_page.dart';
import '../../features/dashboard/daily_check_in_page.dart';
import '../../features/dashboard/my_shops_page.dart';
import '../../features/dashboard/visit_tracker_map_page.dart';
import '../../features/events/events_list_page.dart';

class NavigationItem {
  final String title;
  final IconData icon;
  final Widget page;

  const NavigationItem({
    required this.title,
    required this.icon,
    required this.page,
  });
}

/// A stage in the lead pipeline funnel (Prospect, Qualified, Proposal, ...).
class PipelineStage {
  final String label;
  final int count;
  final Color color;

  const PipelineStage({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// A single point on the revenue trend line chart.
class RevenuePoint {
  final String label;
  final double value;

  const RevenuePoint({required this.label, required this.value});
}

/// A sales rep's ranked performance value, used for the horizontal bar chart.
class RepPerformance {
  final String name;
  final double value;

  const RepPerformance({required this.name, required this.value});
}

/// A deal that is pending / close to closing.
class PendingDeal {
  final String name;
  final String company;
  final double amount;
  final String stage;

  const PendingDeal({
    required this.name,
    required this.company,
    required this.amount,
    required this.stage,
  });
}

/// A field-activity metric shown as a small icon stat chip.
class FieldStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const FieldStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

/// One of the collapsible module sections shown below the main dashboard
/// (Team Performance, Field Activity, Sales Performance, Geographic
/// Coverage, Attendance/Check-in, Consignment, Alerts).
class DashboardSection {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget? destination;

  const DashboardSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.destination,
  });
}

class AgentDashboardPage extends StatefulWidget {
  const AgentDashboardPage({super.key});

  @override
  State<AgentDashboardPage> createState() => _AgentDashboardPageState();
}

class _AgentDashboardPageState extends State<AgentDashboardPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _supervisorName = 'Supervisor';
  String _regionName = 'Nairobi Region';

  int _totalAgentsInRegion = 0;
  int _totalSchoolsInRegion = 0;

  double _monthlyTarget = 100.0;
  double _achievedTarget = 0.0;
  int _visitsCompleted = 0;

  Timer? _midnightAutoCheckoutTimer;
  bool _midnightCheckoutInProgress = false;

  late final List<NavigationItem> _navigationItems;
  late final TabController _tabController;

  // ---------------------------------------------------------------------
  // Sales dashboard data (populated from Supabase in _fetchDashboardMetrics).
  // ---------------------------------------------------------------------
  double _teamRevenue = 0.0;
  double _revenueTargetPct = 0.0;
  int _activeDeals = 0;

  static const _pipelineStageGroups = {
    'lead': 0,
    'contacted': 0,
    'meeting_scheduled': 1,
    'sample_issued': 1,
    'quotation_sent': 2,
    'decision_pending': 2,
    'negotiation': 3,
    'won': 4,
    'lost': 4,
  };

  static const List<String> _pipelineStageLabels = [
    'Prospect',
    'Qualified',
    'Proposal',
    'Negotiation',
    'Closed',
  ];

  static const List<Color> _pipelineStageColors = [
    Colors.blueGrey,
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
  ];

  List<PipelineStage> _pipelineStages = [
    for (int i = 0; i < _pipelineStageLabels.length; i++)
      PipelineStage(
        label: _pipelineStageLabels[i],
        count: 0,
        color: _pipelineStageColors[i],
      ),
  ];

  List<RevenuePoint> _revenueTrend = [];
  List<RepPerformance> _repPerformance = [];
  List<PendingDeal> _topDeals = [];

  List<FieldStat> _fieldStats = [
    const FieldStat(
      label: 'School Visited',
      value: '0',
      icon: Icons.school_outlined,
      color: Color(0xFF3B82F6),
    ),
    const FieldStat(
      label: 'Bookshop Visited',
      value: '0',
      icon: Icons.storefront_outlined,
      color: Color(0xFFF59E0B),
    ),
    const FieldStat(
      label: 'Institution Visited',
      value: '0',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF8B5CF6),
    ),
    const FieldStat(
      label: 'Pipeline',
      value: '0',
      icon: Icons.filter_alt_outlined,
      color: Color(0xFF06B6D4),
    ),
    const FieldStat(
      label: 'Samples Distributed',
      value: '0',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF10B981),
    ),
    FieldStat(
      label: 'Sample Returns',
      value: '0',
      icon: Icons.assignment_return_outlined,
      color: Colors.redAccent.shade200,
    ),
    const FieldStat(
      label: 'Days Worked',
      value: '0',
      icon: Icons.calendar_month_outlined,
      color: Color(0xFF64748B),
    ),
  ];

  late final List<DashboardSection> _dashboardSections = [
    DashboardSection(
      title: 'Team Performance',
      description: 'Rep rankings, quotas and coaching flags for your team.',
      icon: Icons.groups_2_outlined,
      color: AppColors.primaryDark,
      destination: const TeamAttendancePage(),
    ),
    DashboardSection(
      title: 'Field Activity',
      description: 'Visit logs, sample drops and territory coverage.',
      icon: Icons.directions_walk_rounded,
      color: const Color(0xFF3B82F6),
      destination: const VisitTrackerMapPage(),
    ),
    DashboardSection(
      title: 'Sales Performance',
      description: 'Revenue, target attainment and deal velocity.',
      icon: Icons.trending_up_rounded,
      color: const Color(0xFF10B981),
      destination: const TargetPerformancePage(),
    ),
    DashboardSection(
      title: 'Geographic Coverage',
      description: 'Territory heatmaps and region-by-region breakdown.',
      icon: Icons.map_outlined,
      color: const Color(0xFF8B5CF6),
      destination: const VisitTrackerMapPage(),
    ),
    DashboardSection(
      title: 'Attendance / Check-in',
      description: 'Daily check-in / check-out and shift compliance.',
      icon: Icons.fingerprint_rounded,
      color: const Color(0xFFF59E0B),
      destination: const TeamAttendancePage(),
    ),
    DashboardSection(
      title: 'Consignment',
      description: 'Stock on consignment, returns and reconciliation.',
      icon: Icons.inventory_outlined,
      color: const Color(0xFF06B6D4),
      destination: null,
    ),
    DashboardSection(
      title: 'Alerts',
      description: 'Overdue visits, stalled deals and low-stock warnings.',
      icon: Icons.notifications_active_outlined,
      color: Colors.redAccent.shade200,
      destination: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);

    _navigationItems = [
      const NavigationItem(
        title: 'My Schools',
        icon: Icons.school_outlined,
        page: MyShopsPage(),
      ),
      const NavigationItem(
        title: 'Route Plans',
        icon: Icons.alt_route_rounded,
        page: AgentRoutePlanScreen(),
      ),
      const NavigationItem(
        title: 'School Visits',
        icon: Icons.assignment_turned_in_outlined,
        page: AgentSchoolVisitsScreen(),
      ),
      const NavigationItem(
        title: 'Submit Order',
        icon: Icons.shopping_bag_outlined,
        page: AgentSubmitOrderScreen(),
      ),
      const NavigationItem(
        title: 'Distribute Samples',
        icon: Icons.menu_book_outlined,
        page: AgentDistributeSamplesScreen(),
      ),
      const NavigationItem(
        title: 'Detailed Target',
        icon: Icons.insights_rounded,
        page: TargetPerformancePage(),
      ),
      const NavigationItem(
        title: 'Visit Tracker Map',
        icon: Icons.map_outlined,
        page: VisitTrackerMapPage(),
      ),
      const NavigationItem(
        title: 'Team Attendance',
        icon: Icons.fact_check_outlined,
        page: TeamAttendancePage(),
      ),
      const NavigationItem(
        title: 'Team Members',
        icon: Icons.group_add_outlined,
        page: UsersListPage(),
      ),
      const NavigationItem(
        title: 'Regions',
        icon: Icons.domain_rounded,
        page: RegionsManagementPage(),
      ),
      const NavigationItem(
        title: 'User Schools',
        icon: Icons.nature_people_outlined,
        page: UserSchoolOnboardingPage(),
      ),
      const NavigationItem(
        title: 'Events',
        icon: Icons.event_note_rounded,
        page: EventsListPage(),
      ),
    ];

    _fetchSupervisorDashboardData();
    _ensureShiftForCurrentDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightAutoCheckoutTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureShiftForCurrentDay();
    }
  }

  Future<void> _ensureShiftForCurrentDay() async {
    if (_midnightCheckoutInProgress) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _midnightCheckoutInProgress = true;
    try {
      final closed = await DailyShift.autoCheckoutIfNewDay(userId: user.id);
      if (closed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto checked out at midnight to start a new day.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await _scheduleMidnightAutoCheckout(user.id);
    } catch (e) {
      debugPrint('Error applying midnight auto check-out: $e');
    } finally {
      _midnightCheckoutInProgress = false;
    }
  }

  Future<void> _scheduleMidnightAutoCheckout(String userId) async {
    _midnightAutoCheckoutTimer?.cancel();
    try {
      final response =
          await _supabase
              .from('visit_checkins')
              .select('checkin_at')
              .eq('agent_id', userId)
              .isFilter('checkout_at', null)
              .order('checkin_at', ascending: false)
              .limit(1)
              .maybeSingle();
      if (response == null) return;

      final checkInTime =
          DateTime.parse(response['checkin_at'] as String).toLocal();
      final remaining = DailyShift.timeUntilNewDay(checkInTime);
      if (remaining == Duration.zero) {
        await DailyShift.autoCheckoutIfNewDay(userId: userId);
        return;
      }
      _midnightAutoCheckoutTimer = Timer(remaining, _ensureShiftForCurrentDay);
    } catch (e) {
      debugPrint('Error scheduling midnight auto check-out: $e');
    }
  }

  Future<void> _fetchSupervisorDashboardData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profileResponse =
          await _supabase
              .from('profiles')
              .select('full_name, region_id, regions(name)')
              .eq('id', user.id)
              .maybeSingle();

      if (profileResponse != null) {
        _supervisorName = profileResponse['full_name'] ?? 'Supervisor';
        if (profileResponse['regions'] != null) {
          _regionName = profileResponse['regions']['name'] ?? 'Assigned Region';
        }
      }

      final regionId = profileResponse?['region_id'];

      if (regionId != null) {
        final agentsCount = await _supabase
            .from('profiles')
            .select('id')
            .eq('region_id', regionId)
            .eq('role', 'agent');

        final schoolsCount = await _supabase
            .from('schools')
            .select('id')
            .eq('region_id', regionId);

        _totalAgentsInRegion = (agentsCount as List).length;
        _totalSchoolsInRegion = (schoolsCount as List).length;
      }

      final performanceResponse =
          await _supabase
              .from('agent_performance')
              .select('target, achieved, visits_count')
              .eq('user_id', user.id)
              .maybeSingle();

      if (performanceResponse != null) {
        _monthlyTarget = (performanceResponse['target'] ?? 100).toDouble();
        _achievedTarget = (performanceResponse['achieved'] ?? 0).toDouble();
        _visitsCompleted = performanceResponse['visits_count'] ?? 0;
      }

      await _fetchDashboardMetrics(regionId, user.id);
    } catch (e) {
      debugPrint('Error fetching supervisor dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static const List<String> _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const Set<String> _activePipelineStatuses = {
    'lead',
    'contacted',
    'meeting_scheduled',
    'sample_issued',
    'quotation_sent',
    'decision_pending',
    'negotiation',
  };

  /// Maps a [sale_status] value to one of the dashboard's five pipeline
  /// stage indices (0=Prospect, 1=Qualified, 2=Proposal, 3=Negotiation,
  /// 4=Closed).  Returns `null` when the status is not recognised.
  static int? _pipelineStageIndex(String? status) {
    return _pipelineStageGroups[status?.toLowerCase()];
  }

  Future<void> _fetchDashboardMetrics(
    String? regionId,
    String currentUserId,
  ) async {
    try {
      // --- Resolve the set of agent IDs that belong to the current user's
      //     region.  If no region is assigned, fall back to the current user
      //     only so the screen still renders personal data.
      final List<String> agentIds;
      if (regionId != null) {
        final agentsRes = await _supabase
            .from('profiles')
            .select('id')
            .eq('region_id', regionId);
        agentIds =
            (agentsRes as List)
                .map((e) => e['id']?.toString())
                .whereType<String>()
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList()
              ..add(currentUserId);
      } else {
        agentIds = [currentUserId];
      }

      // --- Determine a 6-month window for the revenue-trend chart.
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

      // --- Run all DB reads in parallel.
      final results = await Future.wait<dynamic>([
        // School sales (pipeline, deals, revenue, trend).
        _supabase
            .from('school_sales')
            .select(
              'sale_status, expected_value, agent_id, created_at, school_id',
            )
            .filter('agent_id', 'in', agentIds),

        // School visits (field activity, rep performance).
        _supabase
            .from('school_visits')
            .select('agent_id, school_id, visited_at')
            .filter('agent_id', 'in', agentIds),

        // Sample distributions (field activity).
        _supabase
            .from('school_sample_distributions')
            .select('agent_id, quantity, returned_qty, distributed_at')
            .filter('agent_id', 'in', agentIds),

        // Agent-performance rows for region agents (team target).
        _supabase
            .from('agent_performance')
            .select('target, achieved')
            .filter('user_id', 'in', agentIds),

        // Agent names (for rep-performance chart and top-deals).
        _supabase
            .from('profiles')
            .select('id, full_name')
            .filter('id', 'in', agentIds),

        // Schools (dealer_type for field-stat filtering and school names
        // for top-deals).
        _supabase.from('schools').select('id, name, dealer_type'),
      ]);

      final salesData = List<Map<String, dynamic>>.from(
        (results[0] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final visitsData = List<Map<String, dynamic>>.from(
        (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final distributionsData = List<Map<String, dynamic>>.from(
        (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final performanceData = List<Map<String, dynamic>>.from(
        (results[3] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final profilesData = List<Map<String, dynamic>>.from(
        (results[4] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      final schoolsData = List<Map<String, dynamic>>.from(
        (results[5] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      // Build lookup maps.
      final userNames = <String, String>{};
      for (final p in profilesData) {
        final id = p['id']?.toString();
        final name = p['full_name']?.toString();
        if (id != null && name != null && name.isNotEmpty) {
          userNames[id] = name;
        }
      }

      final schoolNames = <String, String>{};
      final schoolDealerTypes = <String, String>{};
      for (final s in schoolsData) {
        final id = s['id']?.toString();
        if (id != null) {
          schoolNames[id] = s['name']?.toString() ?? '-';
          schoolDealerTypes[id] =
              s['dealer_type']?.toString().toLowerCase() ?? '';
        }
      }

      // --- 1. Pipeline stages (group school_sales by sale_status).
      final stageCounts = List.filled(_pipelineStageLabels.length, 0);
      for (final sale in salesData) {
        final status = sale['sale_status']?.toString();
        final idx = _pipelineStageIndex(status);
        if (idx != null) {
          stageCounts[idx]++;
        }
      }
      _pipelineStages = [
        for (int i = 0; i < _pipelineStageLabels.length; i++)
          PipelineStage(
            label: _pipelineStageLabels[i],
            count: stageCounts[i],
            color: _pipelineStageColors[i],
          ),
      ];

      // --- 2. Active deals (school_sales in active pipeline statuses).
      _activeDeals =
          salesData
              .where(
                (s) => _activePipelineStatuses.contains(
                  (s['sale_status'] as String?)?.toLowerCase() ?? '',
                ),
              )
              .length;

      // --- 3. Team revenue (sum of won school_sales expected_value).
      double teamRevenue = 0;
      for (final sale in salesData) {
        final status = (sale['sale_status'] as String?)?.toLowerCase() ?? '';
        if (status == 'won') {
          final value = (sale['expected_value'] as num?)?.toDouble() ?? 0.0;
          teamRevenue += value;
        }
      }
      _teamRevenue = teamRevenue;

      // --- 4. Revenue trend (monthly sum of won sales, last 6 months).
      final trendMap = <int, double>{}; // key: month index since epoch
      for (final sale in salesData) {
        final status = (sale['sale_status'] as String?)?.toLowerCase() ?? '';
        if (status == 'won') {
          final createdAt = sale['created_at']?.toString();
          final dt = createdAt != null ? DateTime.tryParse(createdAt) : null;
          if (dt != null && !dt.isBefore(sixMonthsAgo)) {
            final key = dt.year * 12 + (dt.month - 1);
            final value = (sale['expected_value'] as num?)?.toDouble() ?? 0.0;
            trendMap[key] = (trendMap[key] ?? 0) + value;
          }
        }
      }
      final trendList = <RevenuePoint>[];
      for (int m = 0; m < 6; m++) {
        final dt = DateTime(now.year, now.month - 5 + m, 1);
        final key = dt.year * 12 + (dt.month - 1);
        final value = (trendMap[key] ?? 0.0) / 1000000; // to millions
        trendList.add(
          RevenuePoint(label: _monthLabels[dt.month - 1], value: value),
        );
      }
      _revenueTrend = trendList;

      // --- 5. Revenue target percentage (team achieved / target).
      double totalTarget = 0;
      double totalAchieved = 0;
      for (final p in performanceData) {
        totalTarget += (p['target'] as num?)?.toDouble() ?? 0.0;
        totalAchieved += (p['achieved'] as num?)?.toDouble() ?? 0.0;
      }
      _revenueTargetPct =
          totalTarget > 0 ? (totalAchieved / totalTarget * 100) : 0.0;

      // --- 6. Rep performance (visit counts by agent).
      final visitsByAgent = <String, int>{};
      final uniqueSchoolsByAgent = <String, Set<String>>{};
      final uniqueDays = <DateTime>{};
      for (final v in visitsData) {
        final agentId = v['agent_id']?.toString() ?? '';
        if (agentId.isEmpty) continue;
        visitsByAgent[agentId] = (visitsByAgent[agentId] ?? 0) + 1;
        final schoolId = v['school_id']?.toString();
        if (schoolId != null && schoolId.isNotEmpty) {
          uniqueSchoolsByAgent
              .putIfAbsent(agentId, () => <String>{})
              .add(schoolId);
        }
        final visitedAt = DateTime.tryParse(v['visited_at']?.toString() ?? '');
        if (visitedAt != null) {
          uniqueDays.add(
            DateTime(visitedAt.year, visitedAt.month, visitedAt.day),
          );
        }
      }

      final repList = <RepPerformance>[];
      for (final entry in visitsByAgent.entries) {
        final name =
            userNames[entry.key] ?? 'Agent ${entry.key.substring(0, 8)}';
        repList.add(RepPerformance(name: name, value: entry.value.toDouble()));
      }
      repList.sort((a, b) => b.value.compareTo(a.value));
      _repPerformance = repList;

      // --- 7. Top deals (top 4 active deals by expected_value).
      final activeSales =
          salesData
              .where(
                (s) => _activePipelineStatuses.contains(
                  (s['sale_status'] as String?)?.toLowerCase() ?? '',
                ),
              )
              .toList()
            ..sort((a, b) {
              final av = (a['expected_value'] as num?)?.toDouble() ?? 0.0;
              final bv = (b['expected_value'] as num?)?.toDouble() ?? 0.0;
              return bv.compareTo(av);
            });

      final stageLabelMap = {
        'lead': 'Prospect',
        'contacted': 'Prospect',
        'meeting_scheduled': 'Qualified',
        'sample_issued': 'Qualified',
        'quotation_sent': 'Proposal',
        'decision_pending': 'Proposal',
        'negotiation': 'Negotiation',
      };

      _topDeals =
          activeSales.take(4).map((sale) {
            final status =
                (sale['sale_status'] as String?)?.toLowerCase() ?? '';
            final schoolId = sale['school_id']?.toString() ?? '';
            return PendingDeal(
              name:
                  schoolNames[schoolId] ??
                  (schoolId.isNotEmpty ? schoolId : 'Unknown'),
              company: schoolNames[schoolId] ?? 'Unknown',
              amount: (sale['expected_value'] as num?)?.toDouble() ?? 0.0,
              stage: stageLabelMap[status] ?? 'Prospect',
            );
          }).toList();

      // --- 8. Field stats.
      int schoolVisitedCount = 0;
      int bookshopVisitedCount = 0;
      int institutionVisitedCount = 0;
      for (final schools in uniqueSchoolsByAgent.values) {
        for (final schoolId in schools) {
          schoolVisitedCount++;
          final dealerType = schoolDealerTypes[schoolId] ?? '';
          if (dealerType == 'bookshop') {
            bookshopVisitedCount++;
          } else if (dealerType == 'institution') {
            institutionVisitedCount++;
          }
        }
      }

      int samplesDistributed = 0;
      int sampleReturns = 0;
      for (final d in distributionsData) {
        samplesDistributed += (d['quantity'] as num?)?.toInt() ?? 0;
        sampleReturns += (d['returned_qty'] as num?)?.toInt() ?? 0;
      }

      final pipelineTotal = stageCounts.fold<int>(0, (a, b) => a + b);

      _fieldStats = [
        FieldStat(
          label: 'School Visited',
          value: schoolVisitedCount.toString(),
          icon: Icons.school_outlined,
          color: const Color(0xFF3B82F6),
        ),
        FieldStat(
          label: 'Bookshop Visited',
          value: bookshopVisitedCount.toString(),
          icon: Icons.storefront_outlined,
          color: const Color(0xFFF59E0B),
        ),
        FieldStat(
          label: 'Institution Visited',
          value: institutionVisitedCount.toString(),
          icon: Icons.account_balance_outlined,
          color: const Color(0xFF8B5CF6),
        ),
        FieldStat(
          label: 'Pipeline',
          value: pipelineTotal.toString(),
          icon: Icons.filter_alt_outlined,
          color: const Color(0xFF06B6D4),
        ),
        FieldStat(
          label: 'Samples Distributed',
          value: samplesDistributed.toString(),
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF10B981),
        ),
        FieldStat(
          label: 'Sample Returns',
          value: sampleReturns.toString(),
          icon: Icons.assignment_return_outlined,
          color: Colors.redAccent.shade200,
        ),
        FieldStat(
          label: 'Days Worked',
          value: uniqueDays.length.toString(),
          icon: Icons.calendar_month_outlined,
          color: const Color(0xFF64748B),
        ),
      ];
    } catch (e) {
      debugPrint('Error fetching dashboard metrics: $e');
    }
  }

  Future<void> _navigateTo(Widget destination) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
    if (mounted) {
      await _ensureShiftForCurrentDay();
    }
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return 'KES ${(value / 1000000).toStringAsFixed(2)}M';
    }
    if (value >= 1000) {
      return 'KES ${(value / 1000).toStringAsFixed(1)}K';
    }
    return 'KES ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Supervisor Dashboard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchSupervisorDashboardData();
              _ensureShiftForCurrentDay();
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: !isWideScreen ? Drawer(child: _buildSidebarContent()) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWideScreen)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _buildSidebarContent(),
            ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                      children: [
                        _buildSalesHeader(),
                        Container(
                          color: AppColors.surfaceWhite,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            labelColor: AppColors.primaryDark,
                            unselectedLabelColor: AppColors.textMuted,
                            indicatorColor: AppColors.primaryGreen,
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            tabs: const [
                              Tab(text: 'Overview'),
                              Tab(text: 'Team'),
                              Tab(text: 'Reports'),
                              Tab(text: 'Goals'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(isWideScreen),
                              _buildTeamTab(isWideScreen),
                              _buildReportsTab(),
                              _buildGoalsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header: "SALES SUPERVISOR DASHBOARD" + "REGION: WEST" style badge.
  // ---------------------------------------------------------------------
  Widget _buildSalesHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primaryDark.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SALES SUPERVISOR DASHBOARD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back, $_supervisorName',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'REGION: ${_regionName.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // OVERVIEW TAB
  // ---------------------------------------------------------------------
  Widget _buildOverviewTab(bool isWideScreen) {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchSupervisorDashboardData();
        await _ensureShiftForCurrentDay();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildKpiCardsRow(isWideScreen),
            const SizedBox(height: 20),
            _buildFieldActivityStrip(),
            const SizedBox(height: 20),
            _buildPerformanceGaugeRow(isWideScreen),
            const SizedBox(height: 20),
            _buildLeadPipelineCard(),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                if (compact) {
                  return Column(
                    children: [
                      _buildRevenueTrendCard(),
                      const SizedBox(height: 20),
                      _buildRepPerformanceCard(),
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _buildRevenueTrendCard()),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: _buildRepPerformanceCard()),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildTopDealsCard(),
            const SizedBox(height: 24),
            _buildModuleSectionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCardsRow(bool isWideScreen) {
    final revenueTrendValues = _revenueTrend.map((p) => p.value).toList();
    final revenueMoM =
        revenueTrendValues.length >= 2
            ? revenueTrendValues.last -
                revenueTrendValues[revenueTrendValues.length - 2]
            : 0.0;
    final revenueMoMUp = revenueMoM >= 0;
    final revenueTrendStr =
        revenueTrendValues.isNotEmpty &&
                revenueTrendValues[revenueTrendValues.length - 2] > 0
            ? '${((revenueMoM / revenueTrendValues[revenueTrendValues.length - 2]) * 100).toStringAsFixed(1)}% MoM'
            : '—';

    final pipelineTotal = _pipelineStages.fold<int>(
      0,
      (sum, s) => sum + s.count,
    );
    final newLeads =
        _pipelineStages.isNotEmpty ? _pipelineStages.first.count : 0;

    final cards = [
      _buildKpiCard(
        title: 'Team Revenue',
        value: _formatCurrency(_teamRevenue),
        icon: Icons.payments_outlined,
        color: const Color(0xFF10B981),
        trend: revenueTrendStr,
        trendUp: revenueMoMUp,
      ),
      _buildKpiCard(
        title: 'Target Achievement',
        value: '${_revenueTargetPct.toStringAsFixed(1)}%',
        icon: Icons.track_changes_rounded,
        color: const Color(0xFF3B82F6),
        trend:
            _revenueTargetPct > 0
                ? '${_revenueTargetPct.toStringAsFixed(1)}% of target'
                : '—',
        trendUp: _revenueTargetPct >= 0,
      ),
      _buildKpiCard(
        title: 'Active Deals',
        value: '$_activeDeals',
        icon: Icons.handshake_outlined,
        color: const Color(0xFFF59E0B),
        trend: '$pipelineTotal total in pipeline',
        trendUp: _activeDeals >= 0,
      ),
      _buildKpiCard(
        title: 'Lead Pipeline',
        value: '$pipelineTotal',
        icon: Icons.filter_alt_outlined,
        color: const Color(0xFF8B5CF6),
        trend: '$newLeads new prospects',
        trendUp: newLeads >= 0,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= 900
                ? 4
                : (constraints.maxWidth >= 560 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.75,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required bool trendUp,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Row(
            children: [
              Icon(
                trendUp
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 13,
                color: trendUp ? const Color(0xFF10B981) : Colors.redAccent,
              ),
              const SizedBox(width: 3),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: trendUp ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Small horizontally-scrolling strip of field-activity icon stats:
  // School Visited | Bookshop Visited | Institution Visited | Pipeline |
  // Samples Distributed | Sample Returns | Days Worked
  Widget _buildFieldActivityStrip() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _fieldStats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final stat = _fieldStats[index];
          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(stat.icon, size: 16, color: stat.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  stat.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Large revenue gauge + target achievement progress bar + active deals.
  Widget _buildPerformanceGaugeRow(bool isWideScreen) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final gauge = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Revenue Performance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                width: 160,
                child: CustomPaint(
                  painter: _GaugePainter(
                    percent: (_revenueTargetPct / 100).clamp(0.0, 1.0),
                    color: AppColors.primaryGreen,
                    trackColor: Colors.grey.shade200,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_revenueTargetPct.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Text(
                          'of target',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(_teamRevenue),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        );

        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTargetProgressCard(),
            const SizedBox(height: 14),
            _buildActiveDealsCard(),
          ],
        );

        if (compact) {
          return Column(
            children: [gauge, const SizedBox(height: 14), rightColumn],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: gauge),
              const SizedBox(width: 14),
              Expanded(flex: 3, child: rightColumn),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetProgressCard() {
    final ratio = (_revenueTargetPct / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target Achievement',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '${_revenueTargetPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade100,
              color: AppColors.primaryGreen,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDealsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Deals',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '$_activeDeals',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Lead pipeline visualization: Prospect, Qualified, Proposal, Negotiation, Closed.
  Widget _buildLeadPipelineCard() {
    final maxCount = _pipelineStages
        .map((s) => s.count)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lead Pipeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ..._pipelineStages.map((stage) {
            final ratio = maxCount > 0 ? stage.count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      stage.label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                height: 16,
                                width: constraints.maxWidth,
                                color: Colors.grey.shade100,
                              ),
                              Container(
                                height: 16,
                                width: constraints.maxWidth * ratio,
                                color: stage.color,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${stage.count}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Total Revenue Trend line chart.
  Widget _buildRevenueTrendCard() {
    final spots = <FlSpot>[
      for (int i = 0; i < _revenueTrend.length; i++)
        FlSpot(i.toDouble(), _revenueTrend[i].value),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Revenue Trend',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monthly revenue, KES millions',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine:
                      (value) =>
                          FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget:
                          (value, meta) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _revenueTrend.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _revenueTrend[idx].label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primaryGreen,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryGreen.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Rep Performance ranked horizontal bar chart.
  Widget _buildRepPerformanceCard() {
    final sorted = [..._repPerformance]
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal =
        sorted.isEmpty
            ? 1.0
            : sorted.map((r) => r.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rep Performance',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(sorted.length, (index) {
            final rep = sorted[index];
            final ratio = maxVal > 0 ? rep.value / maxVal : 0.0;
            final rankColor =
                index == 0
                    ? const Color(0xFF10B981)
                    : (index == 1
                        ? const Color(0xFF3B82F6)
                        : AppColors.textMuted);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: rankColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rep.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  Container(
                                    height: 10,
                                    width: constraints.maxWidth,
                                    color: Colors.grey.shade100,
                                  ),
                                  Container(
                                    height: 10,
                                    width: constraints.maxWidth * ratio,
                                    color: AppColors.primaryGreen,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rep.value.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Top Deals Pending list.
  Widget _buildTopDealsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Deals Pending',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ..._topDeals.map((deal) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.request_quote_outlined,
                      color: AppColors.accentOrange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          deal.company,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(deal.amount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.infoBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          deal.stage,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.infoBlue,
                          ),
                        ),
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

  // Team Performance → Field Activity → Sales Performance → Geographic
  // Coverage → Attendance/Check-in → Consignment → Alerts.
  Widget _buildModuleSectionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard Modules',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ..._dashboardSections.map((section) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap:
                    section.destination != null
                        ? () => _navigateTo(section.destination!)
                        : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${section.title} module coming soon.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: section.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          section.icon,
                          color: section.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              section.description,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // TEAM TAB
  // ---------------------------------------------------------------------
  Widget _buildTeamTab(bool isWideScreen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRepPerformanceCard(),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildNavigationGrid(isWideScreen),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // REPORTS TAB
  // ---------------------------------------------------------------------
  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRevenueTrendCard(),
          const SizedBox(height: 20),
          _buildTopDealsCard(),
          const SizedBox(height: 20),
          _buildModuleSectionsList(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // GOALS TAB
  // ---------------------------------------------------------------------
  Widget _buildGoalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTargetProgressCard(),
          const SizedBox(height: 14),
          _buildPerformanceCard(
            (_monthlyTarget > 0 ? (_achievedTarget / _monthlyTarget) : 0.0)
                .clamp(0.0, 1.0),
          ),
          const SizedBox(height: 20),
          _buildLeadPipelineCard(),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(double progressRatio) {
    final percentVal = (progressRatio * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Personal Target Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                '$percentVal%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressRatio,
              backgroundColor: Colors.grey.shade100,
              color: AppColors.primaryGreen,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${_monthlyTarget.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'Visits: $_visitsCompleted',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.event_available_rounded,
                label: 'View Events',
                color: AppColors.infoBlue,
                onTap: () => _navigateTo(const EventsListPage()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.add_business_rounded,
                label: 'Add New Lead',
                color: AppColors.accentOrange,
                onTap: () => _navigateTo(const MyShopsPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationGrid(bool isWideScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workspace Modules',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _navigationItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWideScreen ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (context, index) {
            final item = _navigationItems[index];
            return Card(
              elevation: 0,
              color: AppColors.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                onTap: () => _navigateTo(item.page),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 28, color: AppColors.primaryDark),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(color: AppColors.primaryDark),
          accountName: Text(
            _supervisorName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          accountEmail: Text(_regionName),
          currentAccountPicture: CircleAvatar(
            backgroundColor: AppColors.primaryGreen,
            child: Text(
              _supervisorName.isNotEmpty
                  ? _supervisorName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(
            Icons.fingerprint_rounded,
            color: AppColors.primaryGreen,
          ),
          title: const Text(
            'Daily Check-In',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => _navigateTo(const DailyCheckInPage()),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _navigationItems.length,
            itemBuilder: (context, index) {
              final item = _navigationItems[index];
              return ListTile(
                dense: true,
                leading: Icon(item.icon, size: 20, color: AppColors.textMuted),
                title: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
                onTap: () {
                  if (Scaffold.of(context).isDrawerOpen) {
                    Navigator.pop(context);
                  }
                  _navigateTo(item.page);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Simple circular gauge painter used for the "Revenue Performance" gauge.
/// Draws a 270° arc track with a colored arc representing [percent].
class _GaugePainter extends CustomPainter {
  final double percent; // 0.0 - 1.0
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.percent,
    required this.color,
    required this.trackColor,
  });

  static const double _startAngle = 2.35619449; // 135deg in radians
  static const double _sweepAngle = 4.71238898; // 270deg in radians

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        (size.width < size.height ? size.width : size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint =
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;

    final progressPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle * percent.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
