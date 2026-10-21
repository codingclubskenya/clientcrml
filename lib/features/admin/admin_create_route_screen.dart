import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../../services/api_service.dart';

class AdminCreateRouteScreen extends StatefulWidget {
  const AdminCreateRouteScreen({super.key});

  @override
  State<AdminCreateRouteScreen> createState() => _AdminCreateRouteScreenState();
}

class _AdminCreateRouteScreenState extends State<AdminCreateRouteScreen> {
  final _dbService = DatabaseService();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  int _selectedRoleFilter = 4;
  List<Map<String, dynamic>> _schools = [];

  String? _selectedUserId;
  final Set<String> _selectedSchoolIds = {};
  DateTime? _selectedDate;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch all assignable users (excluding admins, where role == 1)
      final usersResponse = await ApiService().getAll(
        'users', filter: {'role': {'neq': 1}}, limit: 500,
      );

      // Fetch all schools
      final schoolsResponse = await ApiService().getAll('schools', limit: 500);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(usersResponse);
          _filterUsers();
          _schools = List<Map<String, dynamic>>.from(schoolsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    _filteredUsers =
        _users.where((u) => u['role'] == _selectedRoleFilter).toList();
    if (!_filteredUsers.any((u) => u['id'].toString() == _selectedUserId)) {
      _selectedUserId = null;
    }
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _createRoutePlan() async {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a user')));
      return;
    }

    if (_selectedSchoolIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one school')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date for the route')),
      );
      return;
    }

    try {
      // Create a task payload for each selected school to batch insert
      final tasksToInsert =
          _selectedSchoolIds.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final schoolId = entry.value;

            final school = _schools.firstWhere(
              (s) => s['id'].toString() == schoolId,
            );
            return {
              'title': 'Visit ${school['name']}',
              'description':
                  'Route plan visit for ${school['name']} (Stop ${index + 1})',
              'target_role':
                  -1, // Indicates specific user assignment instead of role
              'assigned_to': _selectedUserId,
              'due_at': _selectedDate!.toIso8601String(),
            };
          }).toList();

      // Bulk insert all created route tasks
      for (final taskPayload in tasksToInsert) {
        await _dbService.insertWithOfflineQueue(
          table: 'tasks',
          payload: Map<String, dynamic>.from(taskPayload),
        );
      }

      final routeDate = _selectedDate!.toIso8601String().split('T').first;
      final routeSchoolIds = _selectedSchoolIds.toList();
      final routeSchoolNames =
          routeSchoolIds.map((schoolId) {
            final school = _schools.firstWhere(
              (s) => s['id'].toString() == schoolId,
            );
            return school['name'] ?? 'Unknown School';
          }).toList();

      await _dbService.insertWithOfflineQueue(
        table: 'route_plans',
        payload: {
          'title': 'Route Plan for $routeDate',
          'route_date': routeDate,
          'assigned_to': _selectedUserId,
          'school_ids': routeSchoolIds,
          'notes': 'Planned stops: ${routeSchoolNames.join(', ')}',
          'status': 'assigned',
          'created_by': _dbService.getCurrentUserId(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route plan created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error creating route plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Route Plan')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Filter by Role:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedRoleFilter,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 2,
                                child: Text('Sales Manager (2)'),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text('BAS (3)'),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text('Agent (4)'),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text('Grounds (5)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRoleFilter = val;
                                  _filterUsers();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select User',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedUserId,
                      items:
                          _filteredUsers.map((user) {
                            return DropdownMenuItem<String>(
                              value: user['id'].toString(),
                              child: Text(
                                user['full_name'] ??
                                    user['email'] ??
                                    'Unknown User',
                              ),
                            );
                          }).toList(),
                      onChanged: (val) => setState(() => _selectedUserId = val),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        _selectedDate == null
                            ? 'Pick Route Date'
                            : 'Route Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDate,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Schools to Visit:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            _schools.isEmpty
                                ? const Center(child: Text('No schools found.'))
                                : ListView.separated(
                                  itemCount: _schools.length,
                                  separatorBuilder:
                                      (context, index) =>
                                          const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final school = _schools[index];
                                    final schoolIdStr = school['id'].toString();
                                    final isSelected = _selectedSchoolIds
                                        .contains(schoolIdStr);

                                    return CheckboxListTile(
                                      title: Text(
                                        school['name'] ?? 'Unnamed School',
                                      ),
                                      value: isSelected,
                                      onChanged: (bool? checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedSchoolIds.add(schoolIdStr);
                                          } else {
                                            _selectedSchoolIds.remove(
                                              schoolIdStr,
                                            );
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createRoutePlan,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Create Route Plan',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
