import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../dashboard/agrovet_onboarding.dart';
import '../dashboard/contacts_page.dart';
import '../dashboard/my_orders_page.dart';
import '../dashboard/sample_distribution_page.dart';
import '../dashboard/grounds_quotation_page.dart';
import '../dashboard/my_shops_page.dart';
import 'bas_alerts_page.dart';
import 'crm_settings_page.dart';
import 'user_profile_page.dart';
import 'messages_page.dart';
import '../../core/constants/grounds_screens.dart';
import '../../core/constants/agent_screens.dart';
import '../../features/database/database_service.dart';
import '../../features/events/events_list_page.dart';
import '../../models/task_model.dart';
import '../project/role5_project_forms_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/region_model.dart';
import '../../models/user_model.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  final DatabaseService _dbService = DatabaseService();
  final PageController _performanceCarouselController = PageController(
    viewportFraction: 0.82,
  );
  late final Future<Map<String, dynamic>> _performanceMetricsFuture;
  Map<String, dynamic>? _cachedPerformanceData;
  bool _showAssignedTasks = false;
  bool _autoHideAssignedTasks = true;
  int _performanceCarouselIndex = 0;
  String? _userName;
  String? _userRegion;
  String? _userSubRegion;
  List<UserModel> _agents = [];
  List<RegionModel> _regions = [];
  bool _isAssignedToEvent = false;

  @override
  void initState() {
    super.initState();
    _performanceMetricsFuture = _loadPerformanceMetrics().then((data) {
      if (mounted) {
        setState(() => _cachedPerformanceData = data);
      }
      return data;
    });
    _loadUserInfo();
    _checkEventAssignment();
  }

  Future<void> _checkEventAssignment() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      final assignments = await Supabase.instance.client
          .from('event_assignments')
          .select('id')
          .eq('agent_id', currentUser.id)
          .limit(1);
      if (mounted) {
        setState(() {
          _isAssignedToEvent = (assignments as List).isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking event assignment: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      final user = await _dbService.getUser(currentUser.id);
      if (!mounted) return;
      if (user == null) return;
      final users = await _dbService.getAllUsers();
      final regions = await _dbService.getAllRegions();
      if (!mounted) return;
      setState(() {
        _userName = user.fullName?.trim().isEmpty ?? true ? null : user.fullName;
        _userRegion = user.region?.trim().isEmpty ?? true ? null : user.region;
        _userSubRegion = user.subRegion?.trim().isEmpty ?? true ? null : user.subRegion;
        _regions = regions;
        _agents = users.where((u) => u.role == 4).toList();
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _assignSupervisor(String? agentId) async {
    if (agentId == null) return;
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;
      final agentMatch = _agents.where((u) => u.id == agentId).toList();
      if (agentMatch.isEmpty) return;
      final agent = agentMatch.first;
      final user = await _dbService.getUser(currentUser.id);
      if (user == null) return;
      final updated = user.copyWith(regionId: agent.regionId, region: agent.region, subRegion: agent.subRegion);
      await _dbService.saveUser(updated);
      if (!mounted) return;
      setState(() {
        _userRegion = agent.region;
        _userSubRegion = agent.subRegion;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supervisor assigned. Region set to ${agent.region}.${agent.subRegion != null ? ' ($agent.subRegion)' : ''}'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign supervisor: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _performanceCarouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF5EE), Color(0xFFF8FCF9)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 700;
            final contentWidth = constraints.maxWidth >= 1200 ? 1100.0 : 900.0;
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildSalesHeader(context, _cachedPerformanceData),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Padding(
                        padding: EdgeInsets.all(isSmall ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "PERFORMANCE",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildMetricsGrid(),
                            const SizedBox(height: 30),
                            Row(
                              children: [
                                const Text(
                                  "ASSIGNED TASKS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  "Auto-hide",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                // Switch.adaptive(
                                //   value: _autoHideAssignedTasks,
                                //   onChanged: (value) {
                                //     setState(() {
                                //       _autoHideAssignedTasks = value;
                                //     });
                                //   },
                                // ),
                                IconButton(
                                  tooltip:
                                      _showAssignedTasks
                                          ? 'Hide tasks'
                                          : 'Show tasks',
                                  icon: Icon(
                                    _showAssignedTasks
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.primaryDark,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showAssignedTasks = !_showAssignedTasks;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_showAssignedTasks)
                              FutureBuilder<List<TaskModel>>(
                                future: _loadAssignedTasks(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        'Failed to load tasks: ${snapshot.error}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    );
                                  }

                                  final tasks =
                                      snapshot.data ?? const <TaskModel>[];
                                  if (tasks.isEmpty) {
                                    return _buildEmptyTaskState();
                                  }
                                  return _buildAssignedTasks(context, tasks);
                                },
                              )
                            else
                              _buildAssignedTasksHiddenState(),
                            const SizedBox(height: 30),
                            const Text(
                              "QUICK ACTIONS",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildQuickActions(context),
                            const SizedBox(height: 30),
                            const Text(
                              "MY LATEST ORDERS",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildEmptyState(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      // Passed context here to enable navigation within the BottomNav
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Future<List<TaskModel>> _loadAssignedTasks() async {
    final role = await _dbService.getCurrentUserRole();
    return _dbService.getTasksForRole(role);
  }

  // --- UI Components ---

  Widget _buildQuickActions(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        "Schools",
        Icons.school_outlined,
        AppColors.primaryGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SchoolOnboarding()),
        ),
      ),
      _QuickAction(
        "Samples",
        Icons.inventory_2_outlined,
        AppColors.secondaryOrange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SampleDistributionPage()),
        ),
      ),
      _QuickAction(
        "Orders",
        Icons.assignment_outlined,
        AppColors.primaryGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyOrdersPage()),
        ),
      ),
      _QuickAction(
        "Messages",
        Icons.chat_bubble_outline,
        AppColors.secondaryOrange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MessagesPage()),
        ),
      ),
      _QuickAction(
        "Contacts",
        Icons.contacts_outlined,
        AppColors.infoBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactsPage()),
        ),
      ),
      _QuickAction(
        "Deliveries",
        Icons.local_shipping_outlined,
        AppColors.infoBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GroundsDeliveriesScreen()),
        ),
      ),
      _QuickAction(
        "Survey",
        Icons.assignment_turned_in_outlined,
        AppColors.infoBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Role5ProjectFormsPage()),
        ),
      ),
      _QuickAction(
        "Quotation",
        Icons.request_quote_outlined,
        AppColors.primaryGreen,
        onTap: () async {
          final role = await _dbService.getCurrentUserRole();
          if (!context.mounted) return;
          if (role != 5) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Only Role 5 can create quotations.')),
            );
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GroundsQuotationPage()),
          );
        },
      ),
    ];

    if (_isAssignedToEvent) {
      actions.insert(
        0,
        _QuickAction(
          "Events",
          Icons.event,
          AppColors.accentOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EventsListPage()),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _actionBtn(action.label, action.icon, action.color, onTap: action.onTap);
      },
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesHeader(BuildContext context, Map<String, dynamic>? performanceData) {
    final monthly = (performanceData ?? _cachedPerformanceData ?? {})['monthly'] as Map<String, dynamic>? ?? {};
    final monthlyVisits = monthly['visits']?.toString() ?? '0';
    final totalMetric = (monthly['visitedSchools'] ?? 0) + (monthly['visits'] ?? 0) + (monthly['orders'] ?? 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;
        return Container(
          padding: EdgeInsets.only(
            top: isCompact ? 48 : 60,
            left: isCompact ? 16 : 24,
            right: isCompact ? 16 : 24,
            bottom: isCompact ? 24 : 32,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF81BD42),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                offset: Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserProfilePage(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          radius: isCompact ? 20 : 24,
                          child: Icon(
                            Icons.person,
                            color: AppColors.textDark,
                            size: isCompact ? 22 : 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome Back,",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isCompact ? 12 : 14,
                            ),
                          ),
                           Text(
                             _userName ?? 'User',
                             style: TextStyle(
                               color: Colors.white,
                               fontSize: isCompact ? 15 : 18,
                               fontWeight: FontWeight.bold,
                               letterSpacing: 0.5,
                             ),
                           ),
                           if (_userRegion != null)
                             Text(
                               _userRegion!,
                               style: TextStyle(
                                 color: Colors.white.withValues(alpha: 0.85),
                                 fontSize: isCompact ? 11 : 12,
                               ),
                             )
                           else
                             Container(
                               margin: const EdgeInsets.only(top: 4),
                               padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: isCompact ? 4 : 6),
                               decoration: BoxDecoration(
                                 color: Colors.white.withValues(alpha: 0.15),
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                               ),
                               child: DropdownButtonHideUnderline(
                                 child: DropdownButton<String>(
                                   value: null,
                                   hint: Text('Select Supervisor', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: isCompact ? 11 : 12)),
                                   icon: Icon(Icons.arrow_drop_down, color: Colors.white.withValues(alpha: 0.9), size: isCompact ? 16 : 18),
                                   items: _agents.map((a) => DropdownMenuItem(value: a.id, child: Text(a.fullName ?? a.email, style: TextStyle(fontSize: isCompact ? 11 : 12)))).toList(),
                                   onChanged: _assignSupervisor,
                                 ),
                               ),
                             ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: isCompact ? 24 : 28,
                        ),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Syncing data...')),
                          );
                          try {
                            await _dbService.syncData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Data synced successfully!'),
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sync failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: isCompact ? 24 : 28,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) async {
                          if (value == 'settings') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CrmSettingsPage(),
                              ),
                            );
                          } else if (value == 'logout') {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            }
                          }
                        },
                        itemBuilder:
                            (BuildContext context) => [
                              PopupMenuItem(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.settings_outlined,
                                      color: AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Settings'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Logout',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 24 : 32),
              // Main Value Area
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's School Visits",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: isCompact ? 13 : 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 12,
                            vertical: isCompact ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textDark.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppColors.textDark,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                               Text(
                                 "$monthlyVisits Visits",
                                 style: TextStyle(
                                   color: AppColors.surfaceWhite,
                                   fontWeight: FontWeight.bold,
                                   fontSize: isCompact ? 11 : 12,
                                 ),
                               ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 12 : 16),
                    Text(
                      "$totalMetric",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 26 : 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: isCompact ? 16 : 20),
                    _buildProgressBarsSection(isCompact: isCompact),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 420;
        final cardWidthFactor = isCompact ? 1.0 : (width < 700 ? 0.92 : 0.72);
        final cardHeight = isCompact ? 188.0 : 196.0;

        return FutureBuilder<Map<String, dynamic>>(
          future: _performanceMetricsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingPerformanceGrid(cardHeight);
            }

            if (snapshot.hasError) {
              return _buildErrorPerformanceGrid(cardHeight, snapshot.error);
            }

            final daily = snapshot.data?['daily'] ?? {};
            final weekly = snapshot.data?['weekly'] ?? {};
            final monthly = snapshot.data?['monthly'] ?? {};
            final yearly = snapshot.data?['yearly'] ?? {};
            final targetsByPeriod =
                snapshot.data?['targetsByPeriod'] as Map<String, dynamic>? ??
                {};
            final dailyTargets =
                targetsByPeriod['daily'] as Map<String, double>? ?? {};
            final weeklyTargets =
                targetsByPeriod['weekly'] as Map<String, double>? ?? {};
            final monthlyTargets =
                targetsByPeriod['monthly'] as Map<String, double>? ?? {};
            final yearlyTargets =
                targetsByPeriod['yearly'] as Map<String, double>? ?? {};
            final performanceCards = [
              (
                "Daily Performance",
                "${daily['percent'] ?? 0}%",
                Icons.today_outlined,
                AppColors.primaryGreen,
                daily['target']?.toString() ??
                    dailyTargets['customer_visits']?.round().toString() ??
                    '0',
                dailyTargets['product_sales']?.round().toString() ??
                    daily['target']?.toString() ??
                    '0',
                daily['wonSales']?.toString() ?? '0',
                daily['visits']?.toString() ?? '0',
              ),
              (
                "Weekly Performance",
                "${weekly['percent'] ?? 0}%",
                Icons.view_week_outlined,
                AppColors.primaryDark,
                weekly['target']?.toString() ??
                    weeklyTargets['customer_visits']?.round().toString() ??
                    '0',
                weeklyTargets['product_sales']?.round().toString() ??
                    weekly['target']?.toString() ??
                    '0',
                weekly['wonSales']?.toString() ?? '0',
                weekly['visits']?.toString() ?? '0',
              ),
              (
                "Monthly Performance",
                "${monthly['percent'] ?? 0}%",
                Icons.calendar_month_outlined,
                AppColors.secondaryOrange,
                monthly['target']?.toString() ??
                    monthlyTargets['customer_visits']?.round().toString() ??
                    '0',
                monthlyTargets['product_sales']?.round().toString() ??
                    monthly['target']?.toString() ??
                    '0',
                monthly['wonSales']?.toString() ?? '0',
                monthly['visits']?.toString() ?? '0',
              ),
              (
                "Yearly Performance",
                "${yearly['percent'] ?? 0}%",
                Icons.insights_outlined,
                AppColors.primaryGreen,
                yearly['target']?.toString() ??
                    yearlyTargets['customer_visits']?.round().toString() ??
                    '0',
                yearlyTargets['product_sales']?.round().toString() ??
                    yearly['target']?.toString() ??
                    '0',
                yearly['wonSales']?.toString() ?? '0',
                yearly['visits']?.toString() ?? '0',
              ),
            ];

            return Column(
              children: [
                SizedBox(
                  height: cardHeight,
                  child: PageView.builder(
                    controller: _performanceCarouselController,
                    itemCount: performanceCards.length,
                    padEnds: false,
                    physics: const PageScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    onPageChanged: (index) {
                      setState(() {
                        _performanceCarouselIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final card = performanceCards[index];
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 8 : 12,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: cardWidthFactor,
                            child: _metricCard(
                              card.$1,
                              card.$2,
                              card.$3,
                              card.$4,
                              compact: isCompact,
                              schoolTarget: card.$5,
                              weeklyTarget: card.$6,
                              institutionLeads: card.$7,
                              weeklyVisits: card.$8,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(performanceCards.length, (index) {
                    final active = index == _performanceCarouselIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 16 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color:
                            active
                                ? AppColors.primaryGreen
                                : AppColors.borderGrey,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadPerformanceMetrics() async {
    final role = await _dbService.getCurrentUserRole();
    final daily = await _dbService.getPerformanceMetrics(
      period: 'daily',
      role: role,
    );
    final weekly = await _dbService.getPerformanceMetrics(
      period: 'weekly',
      role: role,
    );
    final monthly = await _dbService.getPerformanceMetrics(
      period: 'monthly',
      role: role,
    );
    final yearly = await _dbService.getPerformanceMetrics(
      period: 'yearly',
      role: role,
    );

    final dailyTargets = await _dbService.getTargetsForCurrentUser(period: 'daily');
    final weeklyTargets = await _dbService.getTargetsForCurrentUser(period: 'weekly');
    final monthlyTargets = await _dbService.getTargetsForCurrentUser(period: 'monthly');
    final yearlyTargets = await _dbService.getTargetsForCurrentUser(period: 'yearly');
    final targets = monthlyTargets;
    final sampleReturnsData = await _dbService.getSampleDistributions(
      agentId: _dbService.getCurrentUserId(),
    );
    final sampleReturns = sampleReturnsData.fold<int>(
      0,
      (sum, item) => sum + ((item['returned_qty'] as int?) ?? 0),
    );

    int consignments = 0;
    final currentUserId = _dbService.getCurrentUserId();
    if (currentUserId != null) {
      try {
        final consignmentData = await Supabase.instance.client
            .from('orders')
            .select('id')
            .eq('agent_id', currentUserId)
            .eq('order_type', 'consignment');
        consignments = (consignmentData as List).length;
      } catch (e) {
        debugPrint('Error counting consignments: $e');
      }
    }

    return {
      'daily': daily,
      'weekly': weekly,
      'monthly': monthly,
      'yearly': yearly,
      'targets': targets,
      'targetsByPeriod': {
        'daily': dailyTargets,
        'weekly': weeklyTargets,
        'monthly': monthlyTargets,
        'yearly': yearlyTargets,
      },
      'sampleReturns': sampleReturns,
      'sampleReturnsTarget': (monthlyTargets['sample_distribution'] ?? 0).toInt(),
      'consignments': consignments,
      'consignmentsTarget': (monthlyTargets['consignment'] ?? 0).toInt(),
    };
  }

  Widget _buildLoadingPerformanceGrid(double cardHeight) {
    return SizedBox(
      height: cardHeight,
      child: Center(
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPerformanceGrid(double cardHeight, Object? error) {
    return SizedBox(
      height: cardHeight,
      child: Center(
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insights_outlined, color: Colors.orange),
                const SizedBox(height: 8),
                const Text(
                  'Performance metrics could not be loaded.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  error?.toString() ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressBar(
    String label,
    String value,
    double percent,
    Color color, {
    required bool compact,
  }) {
    final percentText = '${(percent * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: compact ? 10 : 11,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 8,
                    vertical: compact ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    percentText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: compact ? 5 : 7,
            value: percent.toDouble(),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBarsSection({required bool isCompact}) {
    final data = _cachedPerformanceData ?? {};
    final monthly = data['monthly'] ?? {};
    final yearly = data['yearly'] ?? {};
    final targets = data['targets'] ?? {};

    final salesTarget = yearly['wonSales'] ?? 0;
    final salesTargetMax = (targets['product_sales'] ?? 0).toDouble();
    final salesPercent = salesTargetMax > 0 ? (salesTarget / salesTargetMax).clamp(0.0, 1.0) : 0.0;

    final visits = monthly['visits'] ?? 0;
    final visitsTarget = (targets['customer_visits'] ?? monthly['target'] ?? 0).toDouble();
    final visitsPercent = visitsTarget > 0 ? (visits / visitsTarget).clamp(0.0, 1.0) : 0.0;

    final collections = monthly['orders'] ?? 0;
    final collectionsTarget = (targets['collections'] ?? 0).toDouble();
    final collectionsPercent = collectionsTarget > 0
        ? (collections / collectionsTarget).clamp(0.0, 1.0)
        : 0.0;

    final newCustomers = monthly['visitedSchools'] ?? 0;
    final newCustomersTarget = (targets['new_customers'] ?? 0).toDouble();
    final newCustomersPercent = newCustomersTarget > 0
        ? (newCustomers / newCustomersTarget).clamp(0.0, 1.0)
        : 0.0;

    final sampleReturns = (data['sampleReturns'] ?? 0) as int;
    final sampleReturnsTarget = (data['sampleReturnsTarget'] ?? 0) as int;
    final sampleReturnsPercent = sampleReturnsTarget > 0
        ? (sampleReturns / sampleReturnsTarget).clamp(0.0, 1.0)
        : 0.0;

    final consignments = (data['consignments'] ?? 0) as int;
    final consignmentsTarget = (data['consignmentsTarget'] ?? 0) as int;
    final consignmentsPercent = consignmentsTarget > 0
        ? (consignments / consignmentsTarget).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        _progressBar(
          'Sales Target',
          'KES $salesTarget / KES ${salesTargetMax.toInt()}',
          salesPercent,
          Colors.white,
          compact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 12),
        _progressBar(
          'Visits',
          '$visits / ${visitsTarget.toInt()}',
          visitsPercent,
          Colors.white,
          compact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 12),
        _progressBar(
          'Collections',
          '$collections / ${collectionsTarget.toInt()}',
          collectionsPercent,
          Colors.white,
          compact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 12),
        _progressBar(
          'New Customers',
          '$newCustomers / ${newCustomersTarget.toInt()}',
          newCustomersPercent,
          Colors.white,
          compact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 12),
        _progressBar(
          'Sample Returns',
          '$sampleReturns / $sampleReturnsTarget',
          sampleReturnsPercent,
          Colors.white,
          compact: isCompact,
        ),
        SizedBox(height: isCompact ? 10 : 12),
        _progressBar(
          'Consignments',
          '$consignments / $consignmentsTarget',
          consignmentsPercent,
          Colors.white,
          compact: isCompact,
        ),
      ],
    );
  }

  Future<void> _markTaskComplete(BuildContext context, TaskModel task) async {
    try {
      await _dbService.updateTaskStatus(task.id, 'closed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task marked as complete.')));
      setState(() {
        if (_autoHideAssignedTasks) _showAssignedTasks = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  Future<void> _deleteTask(BuildContext context, TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Delete "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _dbService.deleteTask(task.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task deleted.')));
      setState(() {
        if (_autoHideAssignedTasks) _showAssignedTasks = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
    }
  }

  Widget _buildAssignedTasks(BuildContext context, List<TaskModel> tasks) {
    return Column(
      children:
          tasks.map((task) {
            final dueText =
                task.dueAt == null
                    ? 'No due date'
                    : '${task.dueAt!.year}-${task.dueAt!.month.toString().padLeft(2, '0')}-${task.dueAt!.day.toString().padLeft(2, '0')}';
            return LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 420;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isCompact ? 38 : 44,
                        height: isCompact ? 38 : 44,
                        decoration: BoxDecoration(
                          color: AppColors.longhornMaroon.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.checklist_rounded,
                          color: AppColors.longhornMaroon,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: isCompact ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isCompact ? 14 : 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              task.description,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: isCompact ? 12 : 13,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_outlined,
                                      size: 15,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dueText,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: isCompact ? 11 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.leafGreen.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    task.status,
                                    style: const TextStyle(
                                      color: AppColors.longhornMaroon,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (task.status.toLowerCase() != 'closed')
                              isCompact
                                  ? Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed:
                                              () => _markTaskComplete(
                                                context,
                                                task,
                                              ),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: const Text('Mark Complete'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              () => _deleteTask(context, task),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Delete'),
                                        ),
                                      ),
                                    ],
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      FilledButton.icon(
                                        onPressed:
                                            () => _markTaskComplete(
                                              context,
                                              task,
                                            ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                        ),
                                        label: const Text('Mark Complete'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed:
                                            () => _deleteTask(context, task),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete'),
                                      ),
                                    ],
                                  )
                            else
                              SizedBox(
                                width: isCompact ? double.infinity : null,
                                child: Align(
                                  alignment:
                                      isCompact
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _deleteTask(context, task),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
    );
  }

  Widget _buildEmptyTaskState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 8),
          const Text(
            'No tasks assigned to your role yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedTasksHiddenState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: const Text(
        'Assigned tasks are hidden. Use the eye icon to show.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool compact,
    required String schoolTarget,
    required String weeklyTarget,
    required String institutionLeads,
    required String weeklyVisits,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          _periodMetricRow('School Target', schoolTarget, compact: compact),
          _periodMetricRow('Weekly Target', weeklyTarget, compact: compact),
          _periodMetricRow(
            'Institution Leads',
            institutionLeads,
            compact: compact,
          ),
          _periodMetricRow('Weekly Visits', weeklyVisits, compact: compact),
        ],
      ),
    );
  }

  Widget _periodMetricRow(String label, String value, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.only(top: compact ? 1 : 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: AppColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.inventory_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            "No visits found for today.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- UPDATED BOTTOM NAVIGATION ---
  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      currentIndex: 0, // Since this is the Dashboard, index 0 is active
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SampleDistributionPage(),
            ),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyShopsPage()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BasAlertsPage()),
          );
        } else if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AgentSubmitOrderScreen(),
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: "Samples",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.school), label: "Onboard"),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none),
          label: "Alerts",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale_outlined),
          label: "Pipeline",
        ),
      ],
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _QuickAction(this.label, this.icon, this.color, {required this.onTap});
}
