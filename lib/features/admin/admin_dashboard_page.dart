import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../../models/farmer_model.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import 'analytics_page.dart';
import 'regions_page.dart';
import 'regions_management_page.dart';
import 'targets_page.dart';
import 'target_performance_page.dart';
import 'ai_assistant_page.dart';
import 'catalog_import_page.dart';
import '../dashboard/my_orders_page.dart';
import '../profile/messages_page.dart';
import '../events/events_list_page.dart';
import '../welcome/auth/login_page.dart';
import 'users_list_page.dart';
import 'assign_books_page.dart';
import 'admin_geofence_map_screen.dart';
import 'admin_pipeline_data_page.dart';
import 'admin_assign_task_screen.dart';
import 'user_school_onboarding_page.dart';
import 'sample_receipts_page.dart';
import 'admin_crm_page.dart';
import 'admin_social_pipeline_page.dart';
import 'project_form_builder_page.dart';
import 'admin_sample_requests_page.dart';
import 'project_form_responses_page.dart';
import 'role2_route_plan_page.dart';
import '../dashboard/sample_distribution_page.dart';
import 'school_profile_page.dart';
import 'admin_individual_performance_page.dart';
import '../../../core/constants/agent_dashboard_page.dart';
import '../../../features/profile/profile_page.dart';
import '../../../core/constants/bas_dashboard_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final DatabaseService _dbService = DatabaseService();
  late Future<_AdminDashboardData> _dashboardFuture;

  Map<String, String> _schoolStages = {};
  String? _selectedUserIdForMap;
  DateTimeRange? _mapDateRange;
  bool _showOnlyCrmSchools = false;
  bool _showRegions = false;
  bool _showTasks = true;
  String? _selectedUserIdForTasks;
  DateTimeRange? _taskDateRange;
  String _taskTimeFilter = 'All'; // 'All', 'Daily', 'Weekly', 'Monthly'
  String _taskStatusFilter = 'All'; // 'All', 'Open', 'In Progress', 'Closed'
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = Future.value(const _AdminDashboardData(
      users: <UserModel>[],
      schools: <SchoolModel>[],
      tasks: <TaskModel>[],
      routePlans: <Map<String, dynamic>>[],
      geofences: <Map<String, dynamic>>[],
    ));
    _enforceRoleAndLoad();
  }

  Future<void> _enforceRoleAndLoad() async {
    final role = await _dbService.getCurrentUserRole();
    // Roles 1-4 can access admin area; role 5 is field agent
    if (role == 5 && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AgentDashboardPage()),
        (route) => false,
      );
      return;
    }
    _dashboardFuture = _loadDashboard();
  }

  Future<_AdminDashboardData> _loadDashboard() async {
    final users = await _dbService.getAllUsers();
    final schools = await _dbService.getAllSchools();
    final tasks = await _dbService.getAllTasks();

    try {
      final salesRes = await Supabase.instance.client
          .from('school_sales')
          .select('school_id, sale_status');

      final Map<String, String> stageMap = {};
      for (var row in (salesRes as List)) {
        final schoolId = (row['school_id'] ?? '').toString();
        final status = (row['sale_status'] ?? '').toString();
        if (schoolId.isNotEmpty) {
          stageMap[schoolId] = status;
        }
      }
      _schoolStages = stageMap;
    } catch (e) {
      debugPrint('Error fetching school sales for map: $e');
    }

    List<Map<String, dynamic>> routePlansData = [];
    try {
      final res = await Supabase.instance.client.from('route_plans').select();
      routePlansData = List<Map<String, dynamic>>.from(
        (res as List).map((x) => Map<String, dynamic>.from(x as Map)),
      );
    } catch (e) {
      debugPrint('Error fetching route plans: $e');
    }

    List<Map<String, dynamic>> geofencesData = [];
    try {
      final resGeo = await Supabase.instance.client.from('geofences').select();
      geofencesData = List<Map<String, dynamic>>.from(
        (resGeo as List).map((x) => Map<String, dynamic>.from(x as Map)),
      );
    } catch (e) {
      debugPrint('Error fetching geofences: $e');
    }

    return _AdminDashboardData(
      users: users,
      schools: schools,
      tasks: tasks,
      routePlans: routePlansData,
      geofences: geofencesData,
    );
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<void> _updateRole(UserModel user, int role) async {
    try {
      await _dbService.updateUserRole(user.id, role);
      _refreshDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.email} updated to role $role'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DeHeusLogin()),
      (route) => false,
    );
  }

  Future<void> _createTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminAssignTaskScreen()),
    );
    _refreshDashboard();
  }

  Future<void> _pickMapDateRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: _mapDateRange,
      helpText: 'Filter Map By Date',
    );
    if (picked == null) return;
    setState(() {
      _mapDateRange = picked;
    });
  }

  void _clearMapDateRange() {
    if (_mapDateRange == null) return;
    setState(() {
      _mapDateRange = null;
    });
  }

  Future<void> _pickTaskDateRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5, 1, 1);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: _taskDateRange,
      helpText: 'Filter Tasks By Date',
    );
    if (picked == null) return;
    setState(() {
      _taskDateRange = picked;
    });
  }

  void _clearTaskDateRange() {
    if (_taskDateRange == null) return;
    setState(() {
      _taskDateRange = null;
    });
  }

  Future<void> _deleteTask(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text('Delete "${task.title}"? This cannot be undone.'),
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
      _refreshDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted successfully.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final isNarrow = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar:
          isDesktop
              ? null
              : AppBar(
                automaticallyImplyLeading: true,
                backgroundColor: const Color(0xFF6D273F),
                toolbarHeight: 44,
                title: const SizedBox.shrink(),
                centerTitle: false,
              ),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(context)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            _buildSidebar(context, isCollapsed: !_isSidebarExpanded),
          Expanded(
            child: FutureBuilder<_AdminDashboardData>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Failed to load dashboard: ${snapshot.error}'),
                  );
                }

                final data =
                    snapshot.data ??
                    const _AdminDashboardData(
                      users: <UserModel>[],
                      schools: <SchoolModel>[],
                      tasks: <TaskModel>[],
                      routePlans: <Map<String, dynamic>>[],
                      geofences: <Map<String, dynamic>>[],
                    );

                List<TaskModel> filteredTasks = data.tasks;

                if (_selectedUserIdForTasks != null) {
                  if (data.users.isNotEmpty) {
                    final selectedUser = data.users.firstWhere(
                      (u) => u.id == _selectedUserIdForTasks,
                      orElse: () => data.users.first,
                    );
                    filteredTasks =
                        filteredTasks.where((t) {
                          return t.targetRole == 0 ||
                              t.targetRole == selectedUser.role;
                        }).toList();
                  } else {
                    filteredTasks = <TaskModel>[];
                  }
                }

                if (_taskTimeFilter != 'All') {
                  final now = DateTime.now();
                  filteredTasks =
                      filteredTasks.where((t) {
                        if (t.dueAt == null) return false;
                        final due = t.dueAt!;
                        if (_taskTimeFilter == 'Daily') {
                          return due.year == now.year &&
                              due.month == now.month &&
                              due.day == now.day;
                        } else if (_taskTimeFilter == 'Weekly') {
                          final startOfWeek = now.subtract(
                            Duration(days: now.weekday % 7),
                          );
                          final endOfWeek = startOfWeek.add(
                            const Duration(days: 6),
                          );
                          final dueDateOnly = DateTime(
                            due.year,
                            due.month,
                            due.day,
                          );
                          final startOnly = DateTime(
                            startOfWeek.year,
                            startOfWeek.month,
                            startOfWeek.day,
                          );
                          final endOnly = DateTime(
                            endOfWeek.year,
                            endOfWeek.month,
                            endOfWeek.day,
                          );
                          return dueDateOnly.isAfter(
                                startOnly.subtract(const Duration(days: 1)),
                              ) &&
                              dueDateOnly.isBefore(
                                endOnly.add(const Duration(days: 1)),
                              );
                        } else if (_taskTimeFilter == 'Monthly') {
                          return due.year == now.year && due.month == now.month;
                        }
                        return true;
                      }).toList();
                }

                if (_taskDateRange != null) {
                  final start = DateTime(
                    _taskDateRange!.start.year,
                    _taskDateRange!.start.month,
                    _taskDateRange!.start.day,
                  );
                  final end = DateTime(
                    _taskDateRange!.end.year,
                    _taskDateRange!.end.month,
                    _taskDateRange!.end.day,
                    23,
                    59,
                    59,
                  );
                  filteredTasks =
                      filteredTasks.where((t) {
                        final due = t.dueAt;
                        if (due == null) return false;
                        return !due.isBefore(start) && !due.isAfter(end);
                      }).toList();
                }

                if (_taskStatusFilter != 'All') {
                  final expectedStatus =
                      _taskStatusFilter == 'In Progress'
                          ? 'in_progress'
                          : _taskStatusFilter.toLowerCase();
                  filteredTasks =
                      filteredTasks.where((t) {
                        return t.status.toLowerCase() == expectedStatus;
                      }).toList();
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshDashboard(),
                  child: ListView(
                    padding: EdgeInsets.all(isNarrow ? 12 : 20),
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 20),
                      _buildSchoolsMap(
                        context,
                        data.schools,
                        data.users,
                        data.routePlans,
                        data.geofences,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            "Regional Performance",
                            subtitle:
                                "Sales targets, school coverage, and YoY growth per region.",
                          ),
                          TextButton.icon(
                            onPressed:
                                () => setState(
                                  () => _showRegions = !_showRegions,
                                ),
                            icon: Icon(
                              _showRegions
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text(
                              _showRegions ? "Hide Regions" : "Show Regions",
                            ),
                          ),
                        ],
                      ),
                      if (_showRegions) ...[
                        const SizedBox(height: 12),
                        const RegionsPage(isEmbedded: true),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            "Tasks",
                            subtitle:
                                "Filter and review tasks assigned to specific people or roles.",
                          ),
                          TextButton.icon(
                            onPressed:
                                () => setState(() => _showTasks = !_showTasks),
                            icon: Icon(
                              _showTasks
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            label: Text(
                              _showTasks ? "Hide Tasks" : "Show Tasks",
                            ),
                          ),
                        ],
                      ),
                      if (_showTasks) ...[
                        const SizedBox(height: 12),
                        if (isNarrow) ...[
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedUserIdForTasks,
                            decoration: InputDecoration(
                              labelText: 'Filter by Person',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Users'),
                              ),
                              ...data.users.map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(
                                    u.fullName ?? u.email,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged:
                                (val) => setState(
                                  () => _selectedUserIdForTasks = val,
                                ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _taskTimeFilter,
                            decoration: InputDecoration(
                              labelText: 'Timeframe',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            items:
                                ['All', 'Daily', 'Weekly', 'Monthly']
                                    .map(
                                      (f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setState(() => _taskTimeFilter = val!),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _taskStatusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                            items:
                                ['All', 'Open', 'In Progress', 'Closed']
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setState(
                                  () => _taskStatusFilter = val ?? 'All',
                                ),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedUserIdForTasks,
                                  decoration: InputDecoration(
                                    labelText: 'Filter by Person',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('All Users'),
                                    ),
                                    ...data.users.map(
                                      (u) => DropdownMenuItem(
                                        value: u.id,
                                        child: Text(
                                          u.fullName ?? u.email,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged:
                                      (val) => setState(
                                        () => _selectedUserIdForTasks = val,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _taskTimeFilter,
                                  decoration: InputDecoration(
                                    labelText: 'Timeframe',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  items:
                                      ['All', 'Daily', 'Weekly', 'Monthly']
                                          .map(
                                            (f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(f),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (val) => setState(
                                        () => _taskTimeFilter = val!,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _taskStatusFilter,
                                  decoration: InputDecoration(
                                    labelText: 'Status',
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  items:
                                      ['All', 'Open', 'In Progress', 'Closed']
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (val) => setState(
                                        () => _taskStatusFilter = val ?? 'All',
                                      ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickTaskDateRange,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text(
                                _taskDateRange == null
                                    ? 'Task Date Filter'
                                    : '${_taskDateRange!.start.year}-${_taskDateRange!.start.month.toString().padLeft(2, '0')}-${_taskDateRange!.start.day.toString().padLeft(2, '0')} -> ${_taskDateRange!.end.year}-${_taskDateRange!.end.month.toString().padLeft(2, '0')}-${_taskDateRange!.end.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                            if (_taskDateRange != null)
                              IconButton(
                                tooltip: 'Clear task date filter',
                                onPressed: _clearTaskDateRange,
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (filteredTasks.isEmpty)
                          _buildEmptyCard(
                            "No tasks match the selected filters.",
                          )
                        else
                          ...filteredTasks.map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TaskCard(
                                task: task,
                                onDelete: () => _deleteTask(task),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        "User Access Control",
                        subtitle:
                            "Promote or demote users directly from Supabase-backed records.",
                      ),
                      const SizedBox(height: 12),
                      if (data.users.isEmpty)
                        _buildEmptyCard("No users found yet.")
                      else
                        ...data.users.map(
                          (user) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _UserRoleCard(
                              user: user,
                              onRoleChanged: (role) => _updateRole(user, role),
                            ),
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
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6D273F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
          SizedBox(height: 8),
          Text(
            "Admin Controls",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Manage tasks, users, and map filters.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.charcoalGrey,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.grey[700])),
        ],
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isCollapsed = false}) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isCollapsed ? 88 : 260,
      color: const Color(0xFF6D273F),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(
              vertical: 30,
              horizontal: isCollapsed ? 8 : 20,
            ),
            width: double.infinity,
            color: AppColors.charcoalGrey.withValues(alpha: 0.2),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 60,
                    color: Colors.white,
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Admin Portal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Publisher Controls',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _createTask,
                          icon: const Icon(Icons.playlist_add, size: 16),
                          label: const Text('Add Task'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _refreshDashboard,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(context, Icons.dashboard, 'Dashboard', () {
                  if (!isDesktop) {
                    Navigator.pop(context);
                  }
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(
                  context,
                  Icons.insights_outlined,
                  'Individual Performance',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => const AdminIndividualPerformancePage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(context, Icons.public, 'Regions', () {
                  if (MediaQuery.of(context).size.width < 800) {
                    Navigator.pop(context);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegionsPage(),
                    ),
                  );
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(context, Icons.manage_accounts, 'Manage Regions', () {
                  if (MediaQuery.of(context).size.width < 800) {
                    Navigator.pop(context);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegionsManagementPage(),
                    ),
                  );
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(context, Icons.track_changes, 'Targets', () {
                  if (MediaQuery.of(context).size.width < 800) {
                    Navigator.pop(context);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TargetsPage(),
                    ),
                  );
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(context, Icons.insights, 'Performance', () {
                  if (MediaQuery.of(context).size.width < 800) {
                    Navigator.pop(context);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TargetPerformancePage(),
                    ),
                  );
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(context, Icons.smart_toy, 'AI Assistant', () {
                  if (MediaQuery.of(context).size.width < 800) {
                    Navigator.pop(context);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiAssistantPage(),
                    ),
                  );
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(context, Icons.event, 'Events', () {
                  if (MediaQuery.of(context).size.width < 800) {
                    Navigator.pop(context);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsListPage(),
                    ),
                  );
                }, isCollapsed: isCollapsed),
                _buildSidebarItem(
                  context,
                  Icons.analytics_outlined,
                  'Analytics',
                  () async {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AnalyticsPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.upload_file,
                  'Import Catalog',
                  () async {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CatalogImportPage(),
                      ),
                    );
                    _refreshDashboard();
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.chat_bubble_outline,
                  'Messages',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MessagesPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.people_outline,
                  'Team Directory',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UsersListPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.school_outlined,
                  'User Schools',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserSchoolOnboardingPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.local_shipping_outlined,
                  'Assign Delivery',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AssignBooksPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.receipt_long_outlined,
                  'Sample Receipts',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SampleReceiptsPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.playlist_add_check_circle_outlined,
                  'Sample Requests',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSampleRequestsPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.shopping_bag_outlined,
                  'Orders & Items',
                  () async {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MyOrdersPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.inventory_2_outlined,
                  'Manage Sample',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SampleDistributionPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.table_chart_outlined,
                  'CRM Workspace',
                  () async {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminCrmPage(),
                      ),
                    );
                    _refreshDashboard();
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.account_tree_outlined,
                  'Pipeline Data',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminPipelineDataPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.assignment_outlined,
                  'Project',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProjectFormBuilderPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.fact_check_outlined,
                  'Project Responses',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProjectFormResponsesPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.route_outlined,
                  'Route Planner',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Role2RoutePlanPage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
                _buildSidebarItem(
                  context,
                  Icons.campaign_outlined,
                  'FB & WhatsApp Pipeline',
                  () {
                    if (MediaQuery.of(context).size.width < 800) {
                      Navigator.pop(context);
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSocialPipelinePage(),
                      ),
                    );
                  },
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSidebarItem(context, Icons.logout, 'Sign Out', () {
                if (!isDesktop) {
                  Navigator.pop(context);
                }
                _signOut();
              }, isCollapsed: isCollapsed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isCollapsed = false,
  }) {
    return ListTile(
      tileColor: Colors.transparent,
      leading: Icon(icon, color: Colors.white70),
      title:
          isCollapsed
              ? null
              : Text(title, style: const TextStyle(color: Colors.white)),
      minLeadingWidth: isCollapsed ? 0 : null,
      horizontalTitleGap: isCollapsed ? 0 : 16,
      contentPadding: EdgeInsets.symmetric(horizontal: isCollapsed ? 28 : 16),
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.1),
      dense: isCollapsed,
    );
  }

  Widget _buildSchoolsMap(
    BuildContext context,
    List<SchoolModel> schools,
    List<UserModel> users,
    List<Map<String, dynamic>> routePlans,
    List<Map<String, dynamic>> geofences,
  ) {
    List<SchoolModel> mapSchools =
        schools
            .where(
              (school) => school.latitude != null && school.longitude != null,
            )
            .toList();

    // CRM Pipeline Alignment Fix
    if (_showOnlyCrmSchools) {
      mapSchools =
          mapSchools.where((s) => _schoolStages.containsKey(s.id)).toList();
    }

    if (_mapDateRange != null) {
      final start = DateTime(
        _mapDateRange!.start.year,
        _mapDateRange!.start.month,
        _mapDateRange!.start.day,
      );
      final end = DateTime(
        _mapDateRange!.end.year,
        _mapDateRange!.end.month,
        _mapDateRange!.end.day,
        23,
        59,
        59,
      );
      mapSchools =
          mapSchools.where((s) {
            final createdAt = s.createdAt;
            if (createdAt == null) return false;
            return !createdAt.isBefore(start) && !createdAt.isAfter(end);
          }).toList();
    }

    List<Map<String, dynamic>> userRoutePlans = [];
    List<Map<String, dynamic>> userGeofences = geofences;

    if (_selectedUserIdForMap != null) {
      userRoutePlans =
          routePlans
              .where((r) => r['assigned_to'] == _selectedUserIdForMap)
              .toList();
      final routeSchoolIds = <String>{};
      for (final r in userRoutePlans) {
        final idsRaw = r['school_ids'];
        if (idsRaw != null) {
          if (idsRaw is List) {
            routeSchoolIds.addAll(idsRaw.map((e) => e.toString()));
          }
        }
      }
      mapSchools =
          mapSchools.where((s) => routeSchoolIds.contains(s.id)).toList();

      userGeofences =
          geofences
              .where((g) => g['assigned_to'] == _selectedUserIdForMap)
              .toList();
    }

    final polylines = _buildRoutePolylines(userRoutePlans, schools);
    final polygons = _buildGeofencePolygons(userGeofences);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 900;
        final mapHeight = isSmall ? 340.0 : 460.0;
        final dateLabel =
            _mapDateRange == null
                ? 'Date Filter'
                : '${_mapDateRange!.start.year}-${_mapDateRange!.start.month.toString().padLeft(2, '0')}-${_mapDateRange!.start.day.toString().padLeft(2, '0')} -> ${_mapDateRange!.end.year}-${_mapDateRange!.end.month.toString().padLeft(2, '0')}-${_mapDateRange!.end.day.toString().padLeft(2, '0')}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSmall) ...[
              _buildSectionHeader(
                "Field Operations Map",
                subtitle:
                    "View school locations, route plans, and assigned geofences.",
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminGeofenceMapScreen(),
                        ),
                      ),
                  icon: const Icon(Icons.add_location_alt, size: 18),
                  label: const Text('Manage Geofences'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.longhornMaroon,
                  ),
                ),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildSectionHeader(
                      "Field Operations Map",
                      subtitle:
                          "View school locations, route plans, and assigned geofences.",
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const AdminGeofenceMapScreen(),
                          ),
                        ),
                    icon: const Icon(Icons.add_location_alt, size: 18),
                    label: const Text('Manage Geofences'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.longhornMaroon,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isSmall ? constraints.maxWidth : 360,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedUserIdForMap,
                        hint: const Text('All Users (No Route Filter)'),
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Users (No Route Filter)'),
                          ),
                          ...{for (var u in users) u.id: u}.values.map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(
                                '${u.fullName ?? u.email} (Role ${u.role})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedUserIdForMap = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickMapDateRange,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(dateLabel),
                ),
                if (_mapDateRange != null)
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: _clearMapDateRange,
                    icon: const Icon(Icons.clear),
                  ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pipeline Only',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Switch(
                      value: _showOnlyCrmSchools,
                      activeTrackColor: AppColors.primaryGreen.withValues(
                        alpha: 0.5,
                      ),
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged:
                          (val) => setState(() => _showOnlyCrmSchools = val),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              height: mapHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        mapSchools.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _selectedUserIdForMap == null
                                      ? (_mapDateRange == null
                                          ? 'No school GPS coordinates found yet.\nSave a school profile to see dots here.'
                                          : 'No schools found for the selected date range.')
                                      : 'No mapped schools or areas found for this filter.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            )
                            : FlutterMap(
                              options: MapOptions(
                                initialCenter: _mapCenter(mapSchools),
                                initialZoom: mapSchools.length > 1 ? 6.3 : 11.5,
                                minZoom: 2,
                                maxZoom: 18,
                                backgroundColor: const Color(0xFFE9EFE8),
                                interactionOptions: const InteractionOptions(
                                  flags:
                                      InteractiveFlag.all &
                                      ~InteractiveFlag.rotate,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'dehus.longhorn.publishers',
                                  maxNativeZoom: 19,
                                  panBuffer: 2,
                                ),
                                PolygonLayer(polygons: polygons),
                                PolylineLayer(polylines: polylines),
                                MarkerLayer(
                                  markers: _schoolMarkers(context, mapSchools),
                                ),
                              ],
                            ),
                  ),
                  if (_showOnlyCrmSchools && mapSchools.isNotEmpty)
                    Positioned(right: 12, top: 12, child: _buildMapLegend()),
                  if (mapSchools.isNotEmpty)
                    Positioned(
                      left: 12,
                      bottom: 12,

                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => _FullScreenMapPage(
                                    schools: mapSchools,
                                    polygons: polygons,
                                    polylines: polylines,
                                    markers: _schoolMarkers(
                                      context,
                                      mapSchools,
                                    ),
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.fullscreen, size: 18),
                        label: const Text('Full Screen'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6D273F),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapLegend() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pipeline Key',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.longhornMaroon,
              ),
            ),
            const Divider(height: 16),
            _legendItem('Lead', Colors.blue),
            _legendItem('Contacted', Colors.teal),
            _legendItem('Proposal', Colors.amber.shade700),
            _legendItem('Negotiation', Colors.deepOrange),
            _legendItem('Won', Colors.green),
            _legendItem('Lost', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  LatLng _mapCenter(List<SchoolModel> schools) {
    if (schools.isEmpty) {
      return const LatLng(-1.286389, 36.817223);
    }

    final latitudes = schools
        .map((school) => school.latitude!.toDouble())
        .toList(growable: false);
    final longitudes = schools
        .map((school) => school.longitude!.toDouble())
        .toList(growable: false);
    final avgLat = latitudes.reduce((a, b) => a + b) / latitudes.length;
    final avgLng = longitudes.reduce((a, b) => a + b) / longitudes.length;
    return LatLng(avgLat, avgLng);
  }

  List<Polygon> _buildGeofencePolygons(List<Map<String, dynamic>> geofences) {
    final polygons = <Polygon>[];
    final colors = [
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.blueGrey,
      Colors.indigo,
    ];
    int colorIndex = 0;

    for (final geo in geofences) {
      final rawPoints = geo['points'] ?? geo['coordinates'] ?? geo['polygon'];
      if (rawPoints is List) {
        final points = <LatLng>[];
        for (final pt in rawPoints) {
          if (pt is Map) {
            final lat = (pt['lat'] ?? pt['latitude']) as num?;
            final lng = (pt['lng'] ?? pt['longitude']) as num?;
            if (lat != null && lng != null) {
              points.add(LatLng(lat.toDouble(), lng.toDouble()));
            }
          } else if (pt is List && pt.length >= 2) {
            points.add(
              LatLng((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
            );
          }
        }
        if (points.length >= 3) {
          final baseColor = colors[colorIndex % colors.length];
          polygons.add(
            Polygon(
              points: points,
              color: baseColor.withValues(alpha: 0.2),
              borderColor: baseColor,
              borderStrokeWidth: 2,
            ),
          );
          colorIndex++;
        }
      }
    }
    return polygons;
  }

  List<Polyline> _buildRoutePolylines(
    List<Map<String, dynamic>> userRoutes,
    List<SchoolModel> allSchools,
  ) {
    final polylines = <Polyline>[];
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    int colorIndex = 0;

    for (final route in userRoutes) {
      final schoolIdsRaw = route['school_ids'];
      if (schoolIdsRaw == null) continue;

      final schoolIds =
          (schoolIdsRaw as List).map((e) => e.toString()).toList();
      final points = <LatLng>[];

      for (final id in schoolIds) {
        final school = allSchools.where((s) => s.id == id).firstOrNull;
        if (school != null &&
            school.latitude != null &&
            school.longitude != null) {
          points.add(
            LatLng(school.latitude!.toDouble(), school.longitude!.toDouble()),
          );
        }
      }

      if (points.length > 1) {
        polylines.add(
          Polyline(
            points: points,
            color: colors[colorIndex % colors.length],
            strokeWidth: 3.5,
          ),
        );
        colorIndex++;
      }
    }
    return polylines;
  }

  String _normalizeStage(String stage) {
    return stage.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  Color _stageColor(String? stage) {
    if (stage == null || stage.isEmpty) return AppColors.longhornMaroon;
    final normalized = _normalizeStage(stage);
    switch (normalized) {
      case 'lead':
        return Colors.blue;
      case 'prospecting':
        return Colors.indigo;
      case 'contacted':
        return Colors.teal;
      case 'meeting_scheduled':
        return Colors.cyan.shade700;
      case 'proposal_sent':
      case 'quotation_sent':
        return Colors.amber.shade700;
      case 'negotiation':
        return Colors.deepOrange;
      case 'won':
      case 'closed_won':
        return Colors.green;
      case 'lost':
      case 'closed_lost':
        return Colors.red;
      default:
        final hash = normalized.hashCode;
        final hue = (hash % 360).toDouble();
        return HSVColor.fromAHSV(1, hue, 0.65, 0.8).toColor();
    }
  }

  List<Marker> _schoolMarkers(BuildContext context, List<SchoolModel> schools) {
    return schools
        .where((school) => school.latitude != null && school.longitude != null)
        .map((school) {
          final stage = _schoolStages[school.id];
          final color = _stageColor(stage);
          return Marker(
            point: LatLng(
              school.latitude!.toDouble(),
              school.longitude!.toDouble(),
            ),
            width: 44, // Slightly larger hit area for easier tapping
            height: 44,
            child: GestureDetector(
              onTap: () => _showSchoolDetails(context, school),
              child: Tooltip(
                message: '${school.name} (${stage ?? 'Lead'})',
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  void _showSchoolDetails(BuildContext context, SchoolModel school) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.school,
                      size: 32,
                      color: AppColors.longhornMaroon,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        school.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Phone Number'),
                  subtitle: Text(
                    school.phone.isEmpty ? 'Not provided' : school.phone,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.map_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('County'),
                  subtitle: Text(
                    school.county.isEmpty ? 'Not provided' : school.county,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.my_location,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('GPS Coordinates'),
                  subtitle: Text(
                    '${school.latitude?.toStringAsFixed(4)}, ${school.longitude?.toStringAsFixed(4)}',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  SchoolProfilePage(schoolId: school.id),
                        ),
                      );
                      _refreshDashboard();
                    },
                    child: const Text(
                      'View Full Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
}

class _FullScreenMapPage extends StatelessWidget {
  const _FullScreenMapPage({
    required this.schools,
    required this.polygons,
    required this.polylines,
    required this.markers,
  });

  final List<SchoolModel> schools;
  final List<Polygon> polygons;
  final List<Polyline> polylines;
  final List<Marker> markers;

  LatLng _mapCenter(List<SchoolModel> schools) {
    final latitudes = schools
        .map((school) => school.latitude!.toDouble())
        .toList(growable: false);
    final longitudes = schools
        .map((school) => school.longitude!.toDouble())
        .toList(growable: false);
    final avgLat = latitudes.reduce((a, b) => a + b) / latitudes.length;
    final avgLng = longitudes.reduce((a, b) => a + b) / longitudes.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Operations Map')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _mapCenter(schools),
          initialZoom: schools.length > 1 ? 6.3 : 11.5,
          minZoom: 2,
          maxZoom: 18,
          backgroundColor: const Color(0xFFE9EFE8),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dehus.longhorn.publishers',
            maxNativeZoom: 19,
            panBuffer: 2,
          ),
          PolygonLayer(polygons: polygons),
          PolylineLayer(polylines: polylines),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

class _UserRoleCard extends StatelessWidget {
  const _UserRoleCard({required this.user, required this.onRoleChanged});

  final UserModel user;
  final ValueChanged<int> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user.role == 1;
    final roleValue = user.role;

    final validRoles = [1, 2, 3, 4, 5];
    final initialRole = validRoles.contains(roleValue) ? roleValue : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.longhornMaroon.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.longhornMaroon,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName?.isNotEmpty == true
                          ? user.fullName!
                          : user.email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email, style: TextStyle(color: Colors.grey[700])),
                    if (user.phone?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.phone!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),
              Chip(
                label: Text(
                  'Role $roleValue',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor:
                    isAdmin
                        ? AppColors.longhornMaroon
                        : AppColors.sageGreyGreen,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: initialRole,
                  decoration: InputDecoration(
                    labelText: 'Role ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  items: [
                    if (initialRole == null)
                      DropdownMenuItem(
                        value: null,
                        child: Text('$roleValue - Unknown'),
                      ),
                    const DropdownMenuItem(value: 1, child: Text('1 - Admin')),
                    const DropdownMenuItem(
                      value: 2,
                      child: Text('2 - Sales Manager'),
                    ),
                    const DropdownMenuItem(value: 3, child: Text('3 - BAS')),
                    const DropdownMenuItem(value: 4, child: Text('4 - Agent')),
                    const DropdownMenuItem(
                      value: 5,
                      child: Text('5 - Grounds Person'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null || value == user.role) return;
                    onRoleChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => onRoleChanged(isAdmin ? 2 : 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(100, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isAdmin ? 'Demote' : 'Promote'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminDashboardData {
  const _AdminDashboardData({
    required this.users,
    required this.schools,
    required this.tasks,
    required this.routePlans,
    required this.geofences,
  });

  final List<UserModel> users;
  final List<SchoolModel> schools;
  final List<TaskModel> tasks;
  final List<Map<String, dynamic>> routePlans;
  final List<Map<String, dynamic>> geofences;
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onDelete});

  final TaskModel task;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dueText =
        task.dueAt == null
            ? 'No due date'
            : '${task.dueAt!.year}-${task.dueAt!.month.toString().padLeft(2, '0')}-${task.dueAt!.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: AppColors.longhornMaroon,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  task.targetRole == 0
                      ? 'All roles'
                      : 'Role ${task.targetRole}',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: AppColors.longhornMaroon,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete task',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(task.description),
          const SizedBox(height: 10),
          Text('Due: $dueText', style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 6),
          Text(
            'Status: ${task.status}',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
