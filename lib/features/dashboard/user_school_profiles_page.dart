import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../admin/school_profile_page.dart';
import '../database/database_service.dart';
import 'agrovet_onboarding.dart';

class UserSchoolProfilesPage extends StatefulWidget {
  const UserSchoolProfilesPage({super.key});

  @override
  State<UserSchoolProfilesPage> createState() => _UserSchoolProfilesPageState();
}

class _UserSchoolProfilesPageState extends State<UserSchoolProfilesPage> {
  final _supabase = Supabase.instance.client;
  final _dbService = DatabaseService();
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _schools = const [];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredSchools {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _schools;
    return _schools.where((school) {
      final haystack = [
        school['name'],
        school['county'],
        school['phone'],
        school['book_category'],
        school['school_ownership'],
        school['contact_name'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _loadSchools() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw StateError('Sign in to view onboarded schools.');
      }

      final response = await _supabase
          .from('schools')
          .select(
            'id,name,phone,county,book_category,dealer_type,shop_category,selected_product,partner_subtype,school_ownership,school_population,contact_name,contact_phone,notes,focusAreas,captured_by,captured_at,updated_at',
          )
          .eq('captured_by', currentUserId)
          .order('updated_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _schools = List<Map<String, dynamic>>.from(
          (response as List).map((item) => Map<String, dynamic>.from(item)),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load onboarded schools: $e')),
      );
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> school) async {
    final nameController = TextEditingController(
      text: school['name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: school['phone']?.toString() ?? '',
    );
    final countyController = TextEditingController(
      text: school['county']?.toString() ?? '',
    );
    final bookCategoryController = TextEditingController(
      text: school['book_category']?.toString() ?? '',
    );
    final ownershipController = TextEditingController(
      text: school['school_ownership']?.toString() ?? '',
    );
    final populationController = TextEditingController(
      text: school['school_population']?.toString() ?? '',
    );
    final contactNameController = TextEditingController(
      text: school['contact_name']?.toString() ?? '',
    );
    final contactPhoneController = TextEditingController(
      text: school['contact_phone']?.toString() ?? '',
    );
    final focusAreasController = TextEditingController(
      text: List<String>.from(school['focusAreas'] ?? const []).join(', '),
    );
    final notesController = TextEditingController(
      text: school['notes']?.toString() ?? '',
    );
    bool isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Edit School Profile'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _editField(nameController, 'School Name'),
                        _editField(
                          phoneController,
                          'Phone',
                          TextInputType.phone,
                        ),
                        _editField(countyController, 'County'),
                        _editField(bookCategoryController, 'Book Category'),
                        _editField(ownershipController, 'Ownership'),
                        _editField(
                          populationController,
                          'Population',
                          TextInputType.number,
                        ),
                        _editField(contactNameController, 'Contact Name'),
                        _editField(
                          contactPhoneController,
                          'Contact Phone',
                          TextInputType.phone,
                        ),
                        _editField(focusAreasController, 'Focus Areas'),
                        _editField(
                          notesController,
                          'Notes',
                          TextInputType.text,
                          3,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    StatefulBuilder(
                      builder:
                          (context, setButtonState) => FilledButton(
                            onPressed:
                                isSaving
                                    ? null
                                    : () async {
                                      if (nameController.text.trim().isEmpty ||
                                          phoneController.text.trim().isEmpty ||
                                          countyController.text
                                              .trim()
                                              .isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Name, phone, and county are required.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final messenger = ScaffoldMessenger.of(
                                        this.context,
                                      );
                                      setDialogState(() => isSaving = true);
                                      setButtonState(() {});
                                      try {
                                        final focusAreas =
                                            focusAreasController.text
                                                .split(',')
                                                .map((value) => value.trim())
                                                .where(
                                                  (value) => value.isNotEmpty,
                                                )
                                                .toList();

                                        await _dbService
                                            .updateByIdWithOfflineQueue(
                                              table: 'schools',
                                              id: school['id'].toString(),
                                              payload: {
                                                'name':
                                                    nameController.text.trim(),
                                                'phone':
                                                    phoneController.text.trim(),
                                                'county':
                                                    countyController.text
                                                        .trim(),
                                                'book_category':
                                                    bookCategoryController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : bookCategoryController
                                                            .text
                                                            .trim(),
                                                'school_ownership':
                                                    ownershipController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : ownershipController
                                                            .text
                                                            .trim(),
                                                'school_population':
                                                    int.tryParse(
                                                      populationController.text
                                                          .trim(),
                                                    ),
                                                'contact_name':
                                                    contactNameController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : contactNameController
                                                            .text
                                                            .trim(),
                                                'contact_phone':
                                                    contactPhoneController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : contactPhoneController
                                                            .text
                                                            .trim(),
                                                'focusAreas':
                                                    focusAreas.isEmpty
                                                        ? const ['General']
                                                        : focusAreas,
                                                'notes':
                                                    notesController.text
                                                            .trim()
                                                            .isEmpty
                                                        ? null
                                                        : notesController.text
                                                            .trim(),
                                                'updated_at':
                                                    DateTime.now()
                                                        .toIso8601String(),
                                              },
                                            );

                                        if (!mounted) return;
                                        Navigator.of(this.context).pop(true);
                                        await _loadSchools();
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'School profile updated.',
                                            ),
                                            backgroundColor:
                                                AppColors.primaryGreen,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not update profile: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setDialogState(
                                            () => isSaving = false,
                                          );
                                          setButtonState(() {});
                                        }
                                      }
                                    },
                            child:
                                isSaving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('Save'),
                          ),
                    ),
                  ],
                ),
          ),
    );

    if (saved != true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile edit cancelled.')));
    }
  }

  Widget _editField(
    TextEditingController controller,
    String label, [
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int count) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
              child: const Icon(Icons.school, color: AppColors.primaryGreen),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const Text('Onboarded schools'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SchoolOnboarding(),
                  ),
                ).then((_) => _loadSchools());
              },
              icon: const Icon(Icons.add),
              label: const Text('Add School'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolCard(Map<String, dynamic> school) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryPale,
                  child: Icon(
                    Icons.school_outlined,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        school['name']?.toString() ?? 'Unnamed school',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [school['county'], school['phone']]
                            .map((value) => value?.toString() ?? '')
                            .where((value) => value.isNotEmpty)
                            .join(' • '),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (school['book_category'] != null)
                  Chip(label: Text(school['book_category'].toString())),
                if (school['school_ownership'] != null)
                  Chip(label: Text(school['school_ownership'].toString())),
                if (school['school_population'] != null)
                  Chip(label: Text('${school['school_population']} learners')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditDialog(school),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => SchoolProfilePage(
                                schoolId: school['id'].toString(),
                              ),
                        ),
                      ).then((_) => _loadSchools());
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schools = _filteredSchools;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Onboarded Schools'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSchools),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchools,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(_schools.length),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search schools, county, phone or category',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (schools.isEmpty)
                _buildEmptyState()
              else
                isDesktop
                    ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.15,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: schools.length,
                      itemBuilder:
                          (context, index) => _buildSchoolCard(schools[index]),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: schools.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, index) => _buildSchoolCard(schools[index]),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No onboarded schools found.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('Onboard a school to start managing its profile.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SchoolOnboarding(),
                  ),
                ).then((_) => _loadSchools());
              },
              icon: const Icon(Icons.add),
              label: const Text('Onboard School'),
            ),
          ],
        ),
      ),
    );
  }
}
