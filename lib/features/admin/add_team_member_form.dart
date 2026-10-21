import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/region_model.dart';
import '../../services/api_service.dart';

class AddTeamMemberForm extends StatefulWidget {
  const AddTeamMemberForm({super.key});

  @override
  State<AddTeamMemberForm> createState() => _AddTeamMemberFormState();
}

class _AddTeamMemberFormState extends State<AddTeamMemberForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regionController = TextEditingController();
  final _subRegionController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;
  bool _regionLoaded = false;
  String? _currentRegionId;
  String? _currentRegion;
  String? _currentSubRegion;
  int _selectedRole = 4; // Default to Agent
  int _currentUserRole = 5;

  static const List<(int, String)> _roleOptions = [
    (2, 'Sales Manager'),
    (3, 'BAS'),
    (4, 'Agent'),
    (5, 'Sales Rep'),
  ];

  List<(int, String)> get _allowedRoleOptions => _roleOptions.where((option) {
    if (_currentUserRole == 1) return option.$1 > 1;
    if (_currentUserRole == 2) return option.$1 == 4 || option.$1 == 5;
    if (_currentUserRole == 3) return option.$1 == 5;
    return false;
  }).toList();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRegion();
  }

  Future<void> _loadCurrentUserRegion() async {
    final currentUserId = _dbService.getCurrentUserId();
    if (currentUserId == null) {
      if (mounted) setState(() => _regionLoaded = true);
      return;
    }
    try {
      final user = await _dbService.getUser(currentUserId);
      if (!mounted) return;
      setState(() {
        _currentUserRole = user?.role ?? 5;
        final options = _allowedRoleOptions;
        if (!options.any((option) => option.$1 == _selectedRole) && options.isNotEmpty) {
          _selectedRole = options.first.$1;
        }
        _currentRegionId = user?.regionId;
        _currentRegion = user?.region;
        _currentSubRegion = user?.subRegion;
        _regionLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading current user region: $e');
      if (mounted) setState(() => _regionLoaded = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _subRegionController.dispose();
    super.dispose();
  }

  Future<void> _createTeamMember() async {
    if (_allowedRoleOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to add team members.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final hasCurrentRegion =
        _currentRegionId != null &&
        (_currentRegion?.trim().isNotEmpty ?? false);
    if (_regionLoaded &&
        !hasCurrentRegion &&
        (_regionController.text.trim().isEmpty ||
            _subRegionController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a region and sub-region.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final tempPassword = const Uuid().v4();

    try {
      String? regionId = _currentRegionId;
      String? regionName = _currentRegion;
      String? subRegion = _currentSubRegion;

      if (regionId == null && _regionLoaded) {
        final createdRegion = await ApiService().create(
          'regions',
          RegionModel(
            region: _regionController.text.trim(),
            subRegion: _subRegionController.text.trim(),
          ).toMap(),
        );
        regionId = createdRegion['id']?.toString();
        regionName = createdRegion['region']?.toString();
        subRegion = createdRegion['sub_region']?.toString();
      }

      final createdUser = await ApiService().createTeamMember(
        email: _emailController.text.trim(),
        password: tempPassword,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
        regionId: regionId,
        region: regionName,
        subRegion: subRegion,
      );
      final createdUserId = createdUser['id']?.toString();
      if (regionId != null) {
        if (createdUserId != null) {
          await _dbService.assignUserToRegion(regionId, createdUserId, _selectedRole);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Team member added successfully.'),
              Text(
                'Email: ${_emailController.text.trim()}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Temporary password: $tempPassword',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Team Member',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter full name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Full name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required';
                  final emailRegex = RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,3}$',
                  );
                  if (!emailRegex.hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: 'Enter phone number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              if (_regionLoaded && _currentRegionId == null) ...[
                const Text(
                  'No region assigned. Create one for this team member.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _regionController,
                  decoration: InputDecoration(
                    labelText: 'Region',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subRegionController,
                  decoration: InputDecoration(
                    labelText: 'Sub-region',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_regionLoaded && _currentRegion != null) ...[
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Assigned region',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '$_currentRegion${_currentSubRegion == null ? '' : ' • $_currentSubRegion'}',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _allowedRoleOptions.any((option) => option.$1 == _selectedRole)
                    ? _selectedRole
                    : null,
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items:
                    _allowedRoleOptions
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                        )
                        .toList(),
                onChanged: _regionLoaded ? (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                } : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !_regionLoaded || _allowedRoleOptions.isEmpty
                      ? null
                      : _createTeamMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text(
                            'Add Team Member',
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
      ),
    );
  }
}
