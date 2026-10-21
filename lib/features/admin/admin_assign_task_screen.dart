import 'package:flutter/material.dart';
import '../database/database_service.dart';
import '../../services/api_service.dart';

class AdminAssignTaskScreen extends StatefulWidget {
  const AdminAssignTaskScreen({super.key});

  @override
  State<AdminAssignTaskScreen> createState() => _AdminAssignTaskScreenState();
}

class _AdminAssignTaskScreenState extends State<AdminAssignTaskScreen> {
  final _dbService = DatabaseService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _selectedTargetRole = 4; // Default to Agent (Role 4)
  bool _assignToAllInRole = true;
  DateTime? _selectedDueDate;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String? _selectedUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all non-admin users so we can filter them by role
  Future<void> _fetchUsers() async {
    try {
      final response = await ApiService().getAll(
        'users', filter: {'role': {'neq': 1}}, limit: 500,
      ); // Exclude other admins

      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(response);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filter the list whenever the role dropdown changes or search text changes
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers =
          _allUsers.where((user) {
            if (user['role'] != _selectedTargetRole) return false;
            if (query.isEmpty) return true;
            final name = (user['full_name'] ?? '').toLowerCase();
            final email = (user['email'] ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();

      // Clear selection if the previously selected user is not in the currently selected role
      final selectedUserHasRole = _allUsers.any(
        (u) => u['id'] == _selectedUserId && u['role'] == _selectedTargetRole,
      );
      if (!selectedUserHasRole) {
        _selectedUserId = null;
      }
    });
  }

  Future<void> _createTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    if (!_assignToAllInRole && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specific person from the list'),
        ),
      );
      return;
    }

    try {
      // If assigning to a specific person, we set target_role to -1.
      // This ensures NO ONE else in the role sees it, only the strictly assigned user.
      final int finalTargetRole = _assignToAllInRole ? _selectedTargetRole : -1;

      await _dbService.insertWithOfflineQueue(
        table: 'tasks',
        payload: {
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'target_role': finalTargetRole,
          'assigned_to': _assignToAllInRole ? null : _selectedUserId,
          if (_selectedDueDate != null)
            'due_at': _selectedDueDate!.toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
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
      appBar: AppBar(title: const Text('Assign New Task')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Task Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Role Selection UI ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Role:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _selectedTargetRole,
                          items: const [
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Sales Manager (Role 2)'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('BAS (Role 3)'),
                            ),
                            DropdownMenuItem(
                              value: 4,
                              child: Text('Agent (Role 4)'),
                            ),
                            DropdownMenuItem(
                              value: 5,
                              child: Text('Grounds Person (Role 5)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedTargetRole = value;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Assign to Entire Role'),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Specific Person in Role'),
                        ),
                      ],
                      selected: {_assignToAllInRole},
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _assignToAllInRole = newSelection.first;
                          if (_assignToAllInRole) {
                            _selectedUserId = null;
                            _searchController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Filtered Users List ---
                    if (!_assignToAllInRole) ...[
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search by Name or Email',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select a user from Role $_selectedTargetRole:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child:
                            _filteredUsers.isEmpty
                                ? const Center(
                                  child: Text('No users found in this role.'),
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListView.separated(
                                    itemCount: _filteredUsers.length,
                                    separatorBuilder:
                                        (context, index) =>
                                            const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final user = _filteredUsers[index];
                                      final isSelected =
                                          user['id'] == _selectedUserId;
                                      return ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.blue
                                            .withValues(alpha: 0.1),
                                        title: Text(
                                          user['full_name'] ??
                                              'No Name provided',
                                        ),
                                        subtitle: Text(
                                          user['email'] ?? 'No Email',
                                        ),
                                        trailing:
                                            isSelected
                                                ? const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.blue,
                                                )
                                                : null,
                                        onTap:
                                            () => setState(
                                              () =>
                                                  _selectedUserId = user['id'],
                                            ),
                                      );
                                    },
                                  ),
                                ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createTask,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Create Task',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
