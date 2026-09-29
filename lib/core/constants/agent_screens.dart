import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../features/admin/role2_route_plan_page.dart';
import '../../features/admin/route_plans_management_page.dart';
import '../../features/dashboard/school_sell_page.dart';

class AgentRoutePlanScreen extends StatefulWidget {
  const AgentRoutePlanScreen({super.key});

  @override
  State<AgentRoutePlanScreen> createState() => _AgentRoutePlanScreenState();
}

class _AgentRoutePlanScreenState extends State<AgentRoutePlanScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _visitations = [];
  List<Map<String, dynamic>> _managedAgents = [];
  List<Map<String, dynamic>> _regionalSchools = [];
  List<Map<String, dynamic>> _routePlans = [];
  List<Map<String, dynamic>> _salesRepAgents = [];

  String? _currentUserRole;
  int _currentUserRoleId = 5;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchUserRole();
    await _fetchRoutePlan();
    await _fetchRoutePlans();
    await _fetchAgents();
    await _fetchSalesRepAgents();
    if (_currentUserRoleId <= 4) {
      await _fetchRegionalSchools();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // Fetch Current User Role
  Future<void> _fetchUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res =
          await _supabase
              .from('users')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
      final role = int.tryParse(res?['role']?.toString() ?? '5') ?? 5;
      _currentUserRoleId = role;
      _currentUserRole = role <= 4 ? 'supervisor' : 'agent';
    } catch (e) {
      debugPrint('Error fetching role: $e');
    }
  }

  // Fetch Route Plan / To-Do List for Selected Date
  Future<void> _fetchRoutePlan() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final formattedDate =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

      var query = _supabase
          .from('visitations')
          .select(
            'id, school_id, visit_date, status, notes, schools(id, name, address)',
          )
          .eq('visit_date', formattedDate);

      // Agents see only their assigned visits; Supervisors see all visits in their area or assigned
      if (_currentUserRoleId >= 5) {
        query = query.eq('assigned_to', user.id);
      }

      final response = await query;
      _visitations = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching route plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load route plan: $e')),
        );
      }
    }
  }

  // Fetch Managed Agents (always loaded — used by assign modal + route form)
  Future<void> _fetchAgents() async {
    try {
      final agentsRes = await _supabase
          .from('users')
          .select('id, full_name, email, role')
          .inFilter('role', [4, 5]);
      _managedAgents = List<Map<String, dynamic>>.from(agentsRes);
    } catch (e) {
      debugPrint('Error fetching agents: $e');
    }
  }

  // Fetch Regional Schools (supervisor/admin only — used by assign modal)
  Future<void> _fetchRegionalSchools() async {
    try {
      final schoolsRes = await _supabase
          .from('schools')
          .select('id, name, address');
      _regionalSchools = List<Map<String, dynamic>>.from(schoolsRes);
    } catch (e) {
      debugPrint('Error fetching school data: $e');
    }
  }

  // Fetch Sales Rep agents (users role 5) — used by the route plan assign-to field
  Future<void> _fetchSalesRepAgents() async {
    try {
      final res = await _supabase
          .from('users')
          .select('id, full_name, email')
          .inFilter('role', [4, 5])
          .order('full_name', ascending: true);
      _salesRepAgents = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching sales reps: $e');
    }
  }

  // Fetch Existing Route Plans (dynamic) — created by role2_route_plan_page.dart
  Future<void> _fetchRoutePlans() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      var query = _supabase
          .from('route_plans')
          .select(
            'id, title, route_date, status, school_ids, notes, assigned_to',
          );

      // Agents only see plans assigned to them
      if (_currentUserRoleId >= 5) {
        query = query.eq('assigned_to', user.id);
      }

      final response = await query.order('route_date', ascending: false);
      final plans = List<Map<String, dynamic>>.from(response);
      if (mounted) {
        setState(() => _routePlans = plans);
      } else {
        _routePlans = plans;
      }
    } catch (e) {
      debugPrint('Error fetching route plans: $e');
    }
  }

  // Toggle Visit Status (To-Do Checkbox)
  Future<void> _toggleVisitStatus(String visitId, bool currentStatus) async {
    final newStatus = currentStatus ? 'pending' : 'completed';

    // Optimistic UI Update
    setState(() {
      final index = _visitations.indexWhere((v) => v['id'] == visitId);
      if (index != -1) {
        _visitations[index]['status'] = newStatus;
      }
    });

    try {
      await _supabase
          .from('visitations')
          .update({'status': newStatus})
          .eq('id', visitId);
    } catch (e) {
      debugPrint('Error updating status: $e');
      _fetchRoutePlan(); // Revert on failure
    }
  }

  // Handle Pick and Bulk Upload File (Excel / CSV)
  Future<void> _handleBulkUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploading route plan file: ${result.files.single.name}...',
          ),
        ),
      );

      try {
        // TODO: Parse CSV/Excel rows here using 'csv' or 'excel' packages,
        // then perform batch insertion into Supabase `visitations` table.

        await Future.delayed(const Duration(seconds: 2)); // Simulated delay

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bulk Route Plan uploaded successfully!'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
          _fetchRoutePlan();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Bulk upload failed: $e')));
        }
      }
    }
  }

  // Open "Assign Visitation" Dialog
  void _showAssignVisitationDialog() {
    String? selectedSchoolId;
    String? selectedAgentId =
        (_currentUserRoleId <= 4) ? null : _supabase.auth.currentUser?.id;
    DateTime assignedDate = _selectedDate;
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_currentUserRoleId <= 4)
                        ? 'Assign Visitation'
                        : 'Add Route Plan',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Select School Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select School',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    items:
                        _regionalSchools.map((school) {
                          return DropdownMenuItem<String>(
                            value: school['id'],
                            child: Text(school['name'] ?? 'Unnamed School'),
                          );
                        }).toList(),
                    onChanged:
                        (val) => setModalState(() => selectedSchoolId = val),
                  ),
                  const SizedBox(height: 12),

                  // Select Field Agent Dropdown (Only for Supervisor/Admin)
                  if (_currentUserRole == 'supervisor' ||
                      _currentUserRole == 'admin') ...[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Assign to Field Agent',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items:
                          _managedAgents.map((agent) {
                            return DropdownMenuItem<String>(
                              value: agent['id'],
                              child: Text(agent['full_name'] ?? 'Agent'),
                            );
                          }).toList(),
                      onChanged:
                          (val) => setModalState(() => selectedAgentId = val),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Notes Input
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Visit Purpose / Instructions',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (selectedSchoolId == null ||
                            selectedAgentId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select both a school and an agent.',
                              ),
                            ),
                          );
                          return;
                        }

                        final formattedDate =
                            "${assignedDate.year}-${assignedDate.month.toString().padLeft(2, '0')}-${assignedDate.day.toString().padLeft(2, '0')}";

                        try {
                          await _supabase.from('visitations').insert({
                            'school_id': selectedSchoolId,
                            'assigned_to': selectedAgentId,
                            'visit_date': formattedDate,
                            'status': 'pending',
                            'notes': notesController.text.trim(),
                            'created_by': _supabase.auth.currentUser?.id,
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Visitation assigned successfully!',
                                ),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                            _fetchRoutePlan();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error assigning visit: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Assign Visit',
                        style: TextStyle(
                          color: AppColors.surfaceWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Add Route Plan selector: select an existing plan or manually create one
  void _showAddRoutePlanSelector() {
    String? selectedRoutePlanId;

    // Manual creation form state
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    DateTime formDate = _selectedDate;
    final currentUserId = _supabase.auth.currentUser?.id;
    // A route plan can be created first and assigned later.
    String? formAssigneeId;
    String planAssigneeSearch = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final bool hasPlans = _routePlans.isNotEmpty;
            // Combined assignable list: unassigned + current user ("Me") + sales reps (role 5)
            final displayAgents = <Map<String, dynamic>>[
              {'id': '', 'full_name': 'Unassigned (assign later)'},
              if (currentUserId != null)
                {
                  'id': currentUserId,
                  'full_name': 'Me',
                  'email': _supabase.auth.currentUser?.email ?? '',
                  'isMe': true,
                },
              ..._salesRepAgents,
            ];
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Route Plan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Existing Route Plan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.route),
                      ),
                      hint: const Text('Select an existing route plan'),
                      items:
                          _routePlans.map((plan) {
                            final date = plan['route_date']?.toString() ?? '';
                            final status = plan['status']?.toString() ?? '';
                            final title =
                                plan['title']?.toString() ?? 'Route Plan';
                            return DropdownMenuItem<String>(
                              value: plan['id'].toString(),
                              child: Text('$title • $date • $status'),
                            );
                          }).toList(),
                      onChanged:
                          (val) =>
                              setModalState(() => selectedRoutePlanId = val),
                    ),
                    if (!hasPlans)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No existing route plans found.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed:
                            selectedRoutePlanId != null
                                ? () {
                                  final id = selectedRoutePlanId!;
                                  Navigator.pop(sheetContext);
                                  _applyExistingRoutePlan(id);
                                }
                                : null,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Load into Checklist'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Create New Route Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Route Date: ${formDate.year}-${formDate.month.toString().padLeft(2, '0')}-${formDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: formDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null)
                          setModalState(() => formDate = picked);
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Assign To',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      decoration: InputDecoration(
                        hintText: 'Search agents / sales reps...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged:
                          (v) => setModalState(() => planAssigneeSearch = v),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 180,
                      child:
                          displayAgents.isEmpty
                              ? const Center(
                                child: Text(
                                  'No agents available.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                              : ListView(
                                padding: EdgeInsets.zero,
                                children:
                                    displayAgents
                                        .where((agent) {
                                          final q =
                                              planAssigneeSearch.toLowerCase();
                                          if (q.isEmpty) return true;
                                          final name =
                                              (agent['full_name'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                          final email =
                                              (agent['email'] ?? '')
                                                  .toString()
                                                  .toLowerCase();
                                          return name.contains(q) ||
                                              email.contains(q);
                                        })
                                        .map((agent) {
                                          final agentId =
                                              agent['id'].toString();
                                          return RadioListTile<String>(
                                            title: Text(
                                              agent['full_name']?.toString() ??
                                                  agent['email']?.toString() ??
                                                  'Agent',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            subtitle:
                                                agent['email'] != null
                                                    ? Text(
                                                      agent['email'].toString(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    )
                                                    : null,
                                            value: agentId,
                                            groupValue: formAssigneeId,
                                            onChanged:
                                                (v) => setModalState(
                                                  () =>
                                                      formAssigneeId =
                                                          v?.isEmpty == true
                                                              ? null
                                                              : v,
                                                ),
                                            contentPadding: EdgeInsets.zero,
                                          );
                                        })
                                        .toList(),
                              ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final title =
                              titleController.text.trim().isEmpty
                                  ? 'Route Plan ${formDate.year}-${formDate.month.toString().padLeft(2, '0')}-${formDate.day.toString().padLeft(2, '0')}'
                                  : titleController.text.trim();
                          final notes = notesController.text.trim();
                          final assignee = formAssigneeId;
                          final date = formDate;
                          Navigator.pop(sheetContext);
                          _createRoutePlanFromForm(
                            title: title,
                            routeDate: date,
                            assignedTo: assignee,
                            notes: notes,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Route Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Role2RoutePlanPage(),
                            ),
                          ).then((_) {
                            _fetchRoutePlans();
                            _fetchRoutePlan();
                          });
                        },
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('Open Full Map Planner'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Shared helper: insert visitations for a set of schools on a given date,
  // skipping any already scheduled for that assignee/date (dynamic DB write).
  Future<int> _insertVisitationsForSchools({
    required List<String> schoolIds,
    required String visitDate,
    required String assignedTo,
    required String notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final existingRes = await _supabase
        .from('visitations')
        .select('school_id')
        .eq('visit_date', visitDate)
        .eq('assigned_to', assignedTo);
    final existingIds =
        (existingRes as List)
            .map((v) => v['school_id']?.toString())
            .whereType<String>()
            .toSet();
    final newSchoolIds =
        schoolIds.where((id) => !existingIds.contains(id)).toList();

    for (final schoolId in newSchoolIds) {
      await _supabase.from('visitations').insert({
        'school_id': schoolId,
        'assigned_to': assignedTo,
        'visit_date': visitDate,
        'status': 'pending',
        'notes': notes,
        'created_by': user.id,
      });
    }
    return newSchoolIds.length;
  }

  // Load an existing route plan's schools into the visitations checklist
  Future<void> _applyExistingRoutePlan(String routePlanId) async {
    final plan = _routePlans.firstWhere(
      (p) => p['id'].toString() == routePlanId,
      orElse: () => <String, dynamic>{},
    );
    if (plan.isEmpty) return;

    final rawSchoolIds = plan['school_ids'];
    final schoolIds = <String>[];
    if (rawSchoolIds is List) {
      schoolIds.addAll(rawSchoolIds.map((e) => e.toString()));
    }
    if (schoolIds.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final String? routeDateStr =
        plan['route_date']?.toString().split('T').first;
    final routeDate =
        routeDateStr ??
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    if (routeDateStr != null) {
      setState(() => _selectedDate = DateTime.parse(routeDateStr));
    }

    setState(() => _isLoading = true);

    try {
      final assignedTo = plan['assigned_to']?.toString() ?? user.id;
      final added = await _insertVisitationsForSchools(
        schoolIds: schoolIds,
        visitDate: routeDate,
        assignedTo: assignedTo,
        notes: plan['notes'] ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added > 0
                  ? '$added stops added from route plan.'
                  : 'All schools from this route plan are already scheduled.',
            ),
            backgroundColor: added > 0 ? AppColors.primaryGreen : null,
          ),
        );
      }
      await _fetchRoutePlan();
    } catch (e) {
      debugPrint('Error applying route plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply route plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Manually create a route plan (dynamic) from the form fields and assign it
  Future<void> _createRoutePlanFromForm({
    required String title,
    required DateTime routeDate,
    String? assignedTo,
    required String notes,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final routeDateStr =
        "${routeDate.year}-${routeDate.month.toString().padLeft(2, '0')}-${routeDate.day.toString().padLeft(2, '0')}";

    // Use the schools currently on the checklist for the selected date
    final schoolIds =
        _visitations
            .where((v) => v['school_id'] != null)
            .map((v) => v['school_id'].toString())
            .toSet()
            .toList();

    setState(() => _selectedDate = routeDate);
    setState(() => _isLoading = true);

    try {
      await _supabase.from('route_plans').insert({
        'title': title,
        'route_date': routeDateStr,
        'assigned_to': assignedTo,
        'school_ids': schoolIds,
        'notes': notes,
        'status': assignedTo == null ? 'draft' : 'assigned',
        'created_by': user.id,
      });

      if (assignedTo != null && schoolIds.isNotEmpty) {
        await _insertVisitationsForSchools(
          schoolIds: schoolIds,
          visitDate: routeDateStr,
          assignedTo: assignedTo,
          notes: notes,
        );

        // Keep the route plan visible as a real to-do item for the assignee.
        for (var i = 0; i < schoolIds.length; i++) {
          final school =
              _visitations.firstWhere(
                (visit) => visit['school_id']?.toString() == schoolIds[i],
                orElse: () => <String, dynamic>{},
              )['schools'];
          await _supabase.from('tasks').insert({
            'title':
                'Visit ${school is Map ? school['name'] ?? 'School' : 'School'}',
            'description':
                notes.isEmpty ? 'Route stop ${i + 1} for $routeDateStr' : notes,
            'target_role': 5,
            'assigned_to': assignedTo,
            'due_at': '${routeDateStr}T09:00:00',
            'status': 'pending',
            'created_by': user.id,
          });
        }
      } else if (assignedTo != null) {
        // A route plan without selected stops is still actionable in the
        // assignee's to-do list.
        await _supabase.from('tasks').insert({
          'title': title,
          'description': notes.isEmpty ? 'Complete assigned route plan' : notes,
          'target_role': 5,
          'assigned_to': assignedTo,
          'due_at': '${routeDateStr}T09:00:00',
          'status': 'pending',
          'created_by': user.id,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route plan "$title" created.'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
      await _fetchRoutePlans();
      await _fetchRoutePlan();
    } catch (e) {
      debugPrint('Error creating route plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create route plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Manage / CRUD all created route plans
  void _showRoutePlansManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child:
                  _routePlans.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No route plans created yet.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                      : ListView.separated(
                        itemCount: _routePlans.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final plan = _routePlans[index];
                          final rawSchoolIds = plan['school_ids'];
                          final stopCount =
                              rawSchoolIds is List ? rawSchoolIds.length : 0;
                          final status =
                              plan['status']?.toString() ?? 'assigned';
                          return ListTile(
                            leading: const Icon(
                              Icons.route,
                              color: AppColors.primaryGreen,
                            ),
                            title: Text(
                              plan['title']?.toString() ?? 'Route Plan',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${plan['route_date']?.toString() ?? ''} • $status • $stopCount stops',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await _editRoutePlan(context, plan);
                                } else if (action == 'delete') {
                                  await _deleteRoutePlan(context, plan);
                                }
                                setModalState(() {});
                              },
                              itemBuilder:
                                  (c) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                            ),
                          );
                        },
                      ),
            );
          },
        );
      },
    );
  }

  void _openRoutePlansPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutePlansManagementPage()),
    ).then((_) async {
      await _fetchRoutePlans();
      await _fetchRoutePlan();
    });
  }

  // Edit an existing route plan (title, notes, status)
  Future<void> _editRoutePlan(
    BuildContext ctx,
    Map<String, dynamic> plan,
  ) async {
    final titleController = TextEditingController(
      text: plan['title']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: plan['notes']?.toString() ?? '',
    );
    final statuses = [
      'draft',
      'submitted',
      'approved',
      'rejected',
      'assigned',
      'in_progress',
      'completed',
    ];
    String selectedStatus = plan['status']?.toString() ?? 'assigned';
    if (!statuses.contains(selectedStatus)) selectedStatus = 'assigned';

    await showDialog(
      context: ctx,
      builder: (dctx) {
        return StatefulBuilder(
          builder: (dctx, dialogSetState) {
            return AlertDialog(
              title: const Text('Edit Route Plan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items:
                          statuses
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                      onChanged:
                          (v) => dialogSetState(() {
                            selectedStatus = v ?? selectedStatus;
                          }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _supabase
                        .from('route_plans')
                        .update({
                          'title': titleController.text.trim(),
                          'notes': notesController.text.trim(),
                          'status': selectedStatus,
                        })
                        .eq('id', plan['id']);
                    Navigator.pop(dctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delete an existing route plan (and its visitations)
  Future<void> _deleteRoutePlan(
    BuildContext ctx,
    Map<String, dynamic> plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder:
          (dctx) => AlertDialog(
            title: const Text('Delete Route Plan'),
            content: Text(
              'Delete "${plan['title']?.toString() ?? 'Route Plan'}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      // Best-effort cleanup of visitations derived from this plan
      try {
        final visitDate = plan['route_date']?.toString().split('T').first;
        final assignedTo = plan['assigned_to']?.toString();
        final rawSchoolIds = plan['school_ids'];
        if (visitDate != null && assignedTo != null && rawSchoolIds is List) {
          final schoolIds =
              rawSchoolIds
                  .map((e) => e.toString())
                  .whereType<String>()
                  .toList();
          if (schoolIds.isNotEmpty) {
            await _supabase
                .from('visitations')
                .delete()
                .eq('visit_date', visitDate)
                .eq('assigned_to', assignedTo)
                .inFilter('school_id', schoolIds);
          }
        }
      } catch (e) {
        debugPrint('Error cleaning up visitations: $e');
      }
      await _supabase.from('route_plans').delete().eq('id', plan['id']);
      _fetchRoutePlans();
      _fetchRoutePlan();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Route plan deleted.')));
      }
    } catch (e) {
      debugPrint('Error deleting route plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete route plan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedVisits =
        _visitations.where((v) => v['status'] == 'completed').length;
    final totalVisits = _visitations.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Route Plan Checklist'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: 'All Route Plans',
            onPressed: _openRoutePlansPage,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload Route Plan',
            onPressed: _handleBulkUpload,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRoutePlanSelector,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          (_currentUserRoleId <= 4) ? 'Assign Route Plan' : 'Add Route Plan',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // --- DATE BAR & PROGRESS SUMMARY ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.surfaceWhite,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                    _isLoading = true;
                                  });
                                  _fetchRoutePlan().then((_) {
                                    setState(() => _isLoading = false);
                                  });
                                }
                              },
                              child: const Text('Change Date'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value:
                              totalVisits > 0
                                  ? completedVisits / totalVisits
                                  : 0,
                          backgroundColor: Colors.grey[200],
                          color: AppColors.primaryGreen,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedVisits of $totalVisits Completed',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              totalVisits > 0
                                  ? '${((completedVisits / totalVisits) * 100).toStringAsFixed(0)}%'
                                  : '0%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // --- TO-DO CHECKLIST LIST ---
                  Expanded(
                    child:
                        _visitations.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_turned_in_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No visits scheduled for this date.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _visitations.length,
                              itemBuilder: (context, index) {
                                final visit = _visitations[index];
                                final school = visit['schools'] ?? {};
                                final isDone = visit['status'] == 'completed';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color:
                                          isDone
                                              ? AppColors.primaryGreen
                                                  .withOpacity(0.5)
                                              : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isDone,
                                    activeColor: AppColors.primaryGreen,
                                    title: Text(
                                      school['name'] ?? 'School Visit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration:
                                            isDone
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                        color:
                                            isDone
                                                ? AppColors.textMuted
                                                : AppColors.textDark,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (school['address'] != null)
                                          Text(
                                            school['address'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (visit['notes'] != null &&
                                            (visit['notes'] as String)
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
                                            child: Text(
                                              'Note: ${visit['notes']}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: AppColors.infoBlue,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    onChanged: (bool? checked) {
                                      if (checked != null) {
                                        _toggleVisitStatus(visit['id'], isDone);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}

class AgentSchoolVisitsScreen extends StatefulWidget {
  const AgentSchoolVisitsScreen({super.key});

  @override
  State<AgentSchoolVisitsScreen> createState() =>
      _AgentSchoolVisitsScreenState();
}

class _AgentSchoolVisitsScreenState extends State<AgentSchoolVisitsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _visits = [];

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('school_visits')
          .select('*, schools(name)')
          .eq('agent_id', userId)
          .order('visited_at', ascending: false);

      setState(() {
        _visits = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading visits: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Visits'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _visits.isEmpty
              ? const Center(child: Text('No visits recorded.'))
              : ListView.builder(
                itemCount: _visits.length,
                itemBuilder: (context, index) {
                  final visit = _visits[index];
                  final schoolName =
                      visit['schools']?['name'] ?? 'Unknown School';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const Icon(
                        Icons.school_outlined,
                        color: AppColors.infoBlue,
                        size: 36,
                      ),
                      title: Text(
                        schoolName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Outcome: ${visit['outcome'] ?? 'N/A'}\nNotes: ${visit['notes'] ?? ''}',
                      ),
                      trailing: Text(
                        visit['visit_status']?.toString().toUpperCase() ?? '',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}

class AgentSubmitOrderScreen extends StatefulWidget {
  const AgentSubmitOrderScreen({super.key});

  @override
  State<AgentSubmitOrderScreen> createState() => _AgentSubmitOrderScreenState();
}

class _AgentSubmitOrderScreenState extends State<AgentSubmitOrderScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _schools = [];

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    try {
      final response = await Supabase.instance.client
          .from('schools')
          .select()
          .order('name');

      setState(() {
        _schools = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading schools: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select School for Order'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _schools.isEmpty
              ? const Center(child: Text('No schools available.'))
              : ListView.builder(
                itemCount: _schools.length,
                itemBuilder: (context, index) {
                  final school = _schools[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryPale,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.accentOrange,
                      ),
                    ),
                    title: Text(
                      school['name'] ?? 'Unknown School',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(school['county'] ?? 'Unknown County'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SchoolSellPage(school: school),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

class AgentDistributeSamplesScreen extends StatefulWidget {
  const AgentDistributeSamplesScreen({super.key});

  @override
  State<AgentDistributeSamplesScreen> createState() =>
      _AgentDistributeSamplesScreenState();
}

class _AgentDistributeSamplesScreenState
    extends State<AgentDistributeSamplesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _samples = [];

  @override
  void initState() {
    super.initState();
    _fetchSamples();
  }

  Future<void> _fetchSamples() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('school_sample_distributions')
          .select('*, schools(name)')
          .eq('agent_id', userId)
          .order('distributed_at', ascending: false);

      setState(() {
        _samples = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading samples: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distributed Samples'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _samples.isEmpty
              ? const Center(child: Text('No samples distributed yet.'))
              : ListView.builder(
                itemCount: _samples.length,
                itemBuilder: (context, index) {
                  final sample = _samples[index];
                  final schoolName =
                      sample['schools']?['name'] ?? 'Unknown School';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.surfaceWhite,
                    child: ListTile(
                      leading: const Icon(
                        Icons.menu_book,
                        color: AppColors.softGold,
                        size: 36,
                      ),
                      title: Text(
                        sample['sample_name'] ?? 'Sample',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'School: $schoolName\nQty Distributed: ${sample['quantity']}\nNotes: ${sample['notes']}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
    );
  }
}
