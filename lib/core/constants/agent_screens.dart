import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
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

  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchUserRole();
    await _fetchRoutePlan();
    if (_currentUserRole == 'supervisor' || _currentUserRole == 'admin') {
      await _fetchAgentsAndSchools();
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
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
      _currentUserRole = res?['role'] ?? 'agent';
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
          .select('id, visit_date, status, notes, schools(id, name, address)')
          .eq('visit_date', formattedDate);

      // Agents see only their assigned visits; Supervisors see all visits in their area or assigned
      if (_currentUserRole == 'agent') {
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

  // Fetch Managed Agents and Regional Schools (for Supervisor Assign Modal)
  Future<void> _fetchAgentsAndSchools() async {
    try {
      final agentsRes = await _supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'agent');
      _managedAgents = List<Map<String, dynamic>>.from(agentsRes);

      final schoolsRes = await _supabase
          .from('schools')
          .select('id, name, address');
      _regionalSchools = List<Map<String, dynamic>>.from(schoolsRes);
    } catch (e) {
      debugPrint('Error fetching helper data: $e');
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
    String? selectedAgentId;
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
                  const Text(
                    'Assign Visitation',
                    style: TextStyle(
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

                  // Select Field Agent Dropdown
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
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Upload Route Plan',
            onPressed: _handleBulkUpload,
          ),
        ],
      ),
      floatingActionButton:
          (_currentUserRole == 'supervisor' || _currentUserRole == 'admin')
              ? FloatingActionButton.extended(
                onPressed: _showAssignVisitationDialog,
                backgroundColor: AppColors.primaryGreen,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Assign Visit',
                  style: TextStyle(color: Colors.white),
                ),
              )
              : null,
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
