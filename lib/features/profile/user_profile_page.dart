import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/colors.dart';
import '../../features/database/database_service.dart';
import '../../models/region_model.dart';
import '../../models/user_model.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idController = TextEditingController();
  bool _isLoading = false;
  File? _photoFile;
  String? _existingPhotoUrl;
  final DatabaseService _dbService = DatabaseService();
  List<UserModel> _agents = [];
  List<RegionModel> _regions = [];
  String? _selectedSupervisorId;
  String? _userRegionId;
  String? _userRegion;
  String? _userSubRegion;
  List<String> _subRegions = [];
  bool _loadingSupervisors = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
    _loadSupervisorsAndRegion();
  }

  Future<void> _loadSupervisorsAndRegion() async {
    setState(() => _loadingSupervisors = true);
    try {
      final users = await _dbService.getAllUsers();
      final regions = await _dbService.getAllRegions();
      final currentUser = Supabase.instance.client.auth.currentUser;
      UserModel? user;
      if (currentUser != null) {
        user = await _dbService.getUser(currentUser.id);
      }
      if (!mounted) return;
      setState(() {
        _agents = users.where((u) => u.role == 4).toList();
        _regions = regions;
        if (user != null) {
          _userRegionId =
              user.regionId?.trim().isEmpty ?? true ? null : user.regionId;
          _userRegion =
              user.region?.trim().isEmpty ?? true ? null : user.region;
          _userSubRegion =
              user.subRegion?.trim().isEmpty ?? true ? null : user.subRegion;
          if (_userRegion != null && _userRegion!.trim().isNotEmpty) {
            final match =
                _agents
                    .where(
                      (a) =>
                          a.region == _userRegion &&
                          a.subRegion == _userSubRegion,
                    )
                    .toList();
            _selectedSupervisorId = match.isNotEmpty ? match.first.id : null;
          }
          if (_userRegion != null) {
            _subRegions = _subRegionsForRegion(_userRegion);
            if (_userSubRegion != null &&
                !_subRegions.contains(_userSubRegion)) {
              _subRegions = [_userSubRegion!, ..._subRegions];
            }
          }
        }
        _loadingSupervisors = false;
      });
    } catch (e) {
      debugPrint('Error loading supervisors: $e');
      if (mounted) setState(() => _loadingSupervisors = false);
    }
  }

  List<String> _subRegionsForRegion(String? region) {
    if (region == null || region.isEmpty) return <String>[];
    return _regions
        .where((r) => r.region == region && r.subRegion.trim().isNotEmpty)
        .map((r) => r.subRegion.trim())
        .toSet()
        .toList();
  }

  Future<void> _onSupervisorChanged(String? agentId) async {
    if (agentId == null) return;
    try {
      final agent = _agents.firstWhere((u) => u.id == agentId);
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (agent.id.isEmpty || currentUser == null) return;
      final user = await _dbService.getUser(currentUser.id);
      if (user == null) return;
      final region = agent.region?.trim().isEmpty ?? true ? null : agent.region;
      final subRegion =
          agent.subRegion?.trim().isEmpty ?? true ? null : agent.subRegion;
      final updated = user.copyWith(
        regionId: agent.regionId,
        region: region,
        subRegion: subRegion,
      );
      await _dbService.saveUser(updated);
      if (!mounted) return;
      setState(() {
        _userRegion = region;
        _userSubRegion = subRegion;
        _selectedSupervisorId = agentId;
        _subRegions = _subRegionsForRegion(region);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Supervisor assigned. Region set to ${region ?? 'none'}.${subRegion != null ? ' ($subRegion)' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign supervisor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onRegionChanged(String? region) async {
    if (region == null) return;
    final matches = _regions.where((r) => r.region == region).toList();
    final regionId = matches.isNotEmpty ? matches.first.id : null;
    final subs = _subRegionsForRegion(region);
    final defaultSub = subs.isNotEmpty ? subs.first : null;
    setState(() {
      _userRegionId = regionId;
      _userRegion = region;
      _userSubRegion = defaultSub;
      _subRegions = subs;
    });
    await _saveRegionOnly(region, defaultSub, regionId);
  }

  Future<void> _onSubRegionChanged(String? subRegion) async {
    if (subRegion == null) return;
    setState(() => _userSubRegion = subRegion);
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final user = await _dbService.getUser(currentUser.id);
    if (user == null) return;
    final updated = user.copyWith(
      regionId: _userRegionId,
      region: _userRegion,
      subRegion: subRegion,
    );
    await _dbService.saveUser(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sub Region updated'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _saveRegionOnly(
    String? region,
    String? subRegion,
    String? regionId,
  ) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final user = await _dbService.getUser(currentUser.id);
    if (user == null) return;
    final updated = user.copyWith(
      regionId: regionId,
      region: region,
      subRegion: subRegion,
    );
    await _dbService.saveUser(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Region updated to $region'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _loadCurrentData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      _nameController.text = meta['full_name'] ?? '';
      _phoneController.text = meta['phone'] ?? '';
      _idController.text = meta['id_number'] ?? '';
      _existingPhotoUrl = meta['avatar_url'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _photoFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No signed-in user found.')),
          );
        }
        return;
      }

      String? photoUrl = _existingPhotoUrl;

      // If a new photo was picked, upload it to Supabase Storage
      if (_photoFile != null) {
        try {
          final fileExt = _photoFile!.path.split('.').last;
          final fileName = '${user.id}_avatar.$fileExt';

          await supabase.storage
              .from('profiles')
              .upload(
                fileName,
                _photoFile!,
                fileOptions: const FileOptions(upsert: true),
              );
          photoUrl = supabase.storage.from('profiles').getPublicUrl(fileName);
        } catch (e) {
          debugPrint('Photo upload failed (does the bucket exist?): $e');
        }
      }

      // Prepare metadata updates
      final updates = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'id_number': _idController.text.trim(),
      };
      if (photoUrl != null) {
        updates['avatar_url'] = photoUrl;
      }

      // Save to Supabase Auth metadata
      await supabase.auth.updateUser(UserAttributes(data: updates));

      // Save region/subregion to users table
      try {
        final existing = await _dbService.getUser(user.id);
        if (existing != null) {
          final updatedUser = existing.copyWith(
            fullName: _nameController.text.trim(),
            region: _userRegion,
            subRegion: _userSubRegion,
          );
          await _dbService.saveUser(updatedUser);
        }
      } catch (e) {
        debugPrint('Error saving user region: $e');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Personal Info'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
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
            final isSmallScreen = constraints.maxWidth < 700;
            final contentWidth = constraints.maxWidth > 980 ? 920.0 : 720.0;
            final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isSmallScreen ? 16 : 24,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Card(
                    elevation: 0,
                    color: Colors.white.withValues(alpha: 0.96),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: AppColors.borderGrey),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      child:
                          isSmallScreen
                              ? _buildMobileLayout(context)
                              : _buildWideLayout(context),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAvatarSection(),
        const SizedBox(height: 24),
        _buildFormFields(),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [const SizedBox(height: 8), _buildAvatarSection()],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(child: _buildFormFields()),
      ],
    );
  }

  Widget _buildAvatarSection() {
    final ImageProvider? imageProvider =
        _photoFile != null
            ? FileImage(_photoFile!)
            : _existingPhotoUrl != null
            ? NetworkImage(_existingPhotoUrl!)
            : null;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: CircleAvatar(
            radius: 56,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: imageProvider,
            child:
                imageProvider == null
                    ? const Icon(Icons.camera_alt, size: 42, color: Colors.grey)
                    : null,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Tap to change photo',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    final allRegions = _regions.map((r) => r.region).toSet().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Update your contact details and profile photo.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 520;
            if (isNarrow) {
              return Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'ID Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value:
                        _selectedSupervisorId == null ||
                                _selectedSupervisorId!.isEmpty ||
                                !_agents.any(
                                  (a) => a.id == _selectedSupervisorId,
                                )
                            ? null
                            : _selectedSupervisorId,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor',
                      border: OutlineInputBorder(),
                    ),
                    hint: Text(
                      _loadingSupervisors ? 'Loading...' : 'Select Supervisor',
                    ),
                    items:
                        _agents
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.fullName ?? a.email),
                              ),
                            )
                            .toList(),
                    onChanged:
                        _loadingSupervisors ? null : _onSupervisorChanged,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value:
                        _userRegion == null || !allRegions.contains(_userRegion)
                            ? null
                            : _userRegion,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select Region'),
                    items:
                        allRegions
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                    onChanged: _onRegionChanged,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value:
                        _userSubRegion == null ||
                                !_subRegions.contains(_userSubRegion)
                            ? null
                            : _userSubRegion,
                    decoration: const InputDecoration(
                      labelText: 'Sub Region',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select Sub Region'),
                    items:
                        _subRegions
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: _userRegion == null ? null : _onSubRegionChanged,
                  ),
                ],
              );
            }

            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'ID Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value:
                      _selectedSupervisorId == null ||
                              _selectedSupervisorId!.isEmpty ||
                              !_agents.any((a) => a.id == _selectedSupervisorId)
                          ? null
                          : _selectedSupervisorId,
                  decoration: const InputDecoration(
                    labelText: 'Supervisor',
                    border: OutlineInputBorder(),
                  ),
                  hint: Text(
                    _loadingSupervisors ? 'Loading...' : 'Select Supervisor',
                  ),
                  items:
                      _agents
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.fullName ?? a.email),
                            ),
                          )
                          .toList(),
                  onChanged: _loadingSupervisors ? null : _onSupervisorChanged,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            _userRegion == null ||
                                    !allRegions.contains(_userRegion)
                                ? null
                                : _userRegion,
                        decoration: const InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select Region'),
                        items:
                            allRegions
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r),
                                  ),
                                )
                                .toList(),
                        onChanged: _onRegionChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            _userSubRegion == null ||
                                    !_subRegions.contains(_userSubRegion)
                                ? null
                                : _userSubRegion,
                        decoration: const InputDecoration(
                          labelText: 'Sub Region',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select Sub Region'),
                        items:
                            _subRegions
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _userRegion == null ? null : _onSubRegionChanged,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Save Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}
