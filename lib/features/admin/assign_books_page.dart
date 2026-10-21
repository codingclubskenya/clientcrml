import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../services/api_service.dart';

class AssignBooksPage extends StatefulWidget {
  const AssignBooksPage({super.key});

  @override
  State<AssignBooksPage> createState() => _AssignBooksPageState();
}

class _AssignBooksPageState extends State<AssignBooksPage> {
  final _dbService = DatabaseService();
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _groundsUsers = [];
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _books = [];

  String? _selectedUserId;
  String? _selectedSchoolId;
  Map<String, dynamic>? _selectedBook;

  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      // Fetch users with Role 5 (Grounds Person)
      final usersResponse = await ApiService().getAll(
        'users', filter: {'role': 5}, limit: 500,
      );
      // Fetch all schools
      final schoolsResponse = await ApiService().getAll(
        'schools', orderBy: 'name', orderDir: 'ASC', limit: 500,
      );
      // Fetch all catalog items
      final booksResponse = await ApiService().getAll(
        'catalog_items', filter: {'is_active': true},
        orderBy: 'name', orderDir: 'ASC', limit: 500,
      );

      if (mounted) {
        setState(() {
          _groundsUsers = List<Map<String, dynamic>>.from(usersResponse);
          _schools = List<Map<String, dynamic>>.from(schoolsResponse);
          _books = List<Map<String, dynamic>>.from(booksResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assignment data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignDelivery() async {
    if (_selectedUserId == null ||
        _selectedSchoolId == null ||
        _selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a User, School, and Book.'),
        ),
      );
      return;
    }

    final qty = int.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _dbService.recordSampleDistribution(
        schoolId: _selectedSchoolId!,
        sampleName: _selectedBook!['name'],
        sampleCategory: _selectedBook!['category'] ?? 'Assigned Book',
        agentId: _selectedUserId,
        quantity: qty,
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : 'Delivery Assignment',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Books assigned to Grounds personnel (or queued offline)!',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Delivery Books'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule Book Delivery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Assign a book from the catalog for a Role 5 user to deliver to a school.',
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Grounds User (Role 5)',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedUserId,
                      items:
                          _groundsUsers.map((user) {
                            return DropdownMenuItem<String>(
                              value: user['id'].toString(),
                              child: Text(
                                user['full_name'] ?? user['email'] ?? 'Unknown',
                              ),
                            );
                          }).toList(),
                      onChanged: (val) => setState(() => _selectedUserId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Target School',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedSchoolId,
                      items:
                          _schools.map((school) {
                            return DropdownMenuItem<String>(
                              value: school['id'].toString(),
                              child: Text(school['name'] ?? 'Unnamed School'),
                            );
                          }).toList(),
                      onChanged:
                          (val) => setState(() => _selectedSchoolId = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Select Book/Sample',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedBook,
                      items:
                          _books.map((book) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: book,
                              child: Text(
                                '${book['name']} (${book['category']})',
                              ),
                            );
                          }).toList(),
                      onChanged: (val) => setState(() => _selectedBook = val),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity to Deliver',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Notes / Instructions',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _assignDelivery,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        icon:
                            _isSaving
                                ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.local_shipping),
                        label: const Text(
                          'Assign Delivery to User',
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
  }
}
