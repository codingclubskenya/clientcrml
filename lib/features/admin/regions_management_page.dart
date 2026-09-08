import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/region_model.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

const List<String> _kenyanCounties = [
  'Nairobi',
  'Mombasa',
  'Kisumu',
  'Nakuru',
  'Kiambu',
  'Kajiado',
  'Narok',
  'Kericho',
  'Kisii',
  'Nyamira',
  'Kakamega',
  'Vihiga',
  'Bungoma',
  'Busia',
  'Siaya',
  'Homa Bay',
  'Migori',
  'Kitui',
  'Machakos',
  'Makueni',
  'Embu',
  'Meru',
  'Tharaka-Nithi',
  'Nyeri',
  'Kirinyaga',
  'Murang\'a',
  'Nanyuki',
  'Laikipia',
  'Eldoret',
  'Kapsabet',
  'Kapenguria',
  'Lodwar',
  'Marsabit',
  'Garissa',
  'Wajir',
  'Mandera',
  'Isiolo',
  'Voi',
];

class RegionsManagementPage extends StatefulWidget {
  const RegionsManagementPage({super.key});

  @override
  State<RegionsManagementPage> createState() => _RegionsManagementPageState();
}

class _RegionsManagementPageState extends State<RegionsManagementPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _searchQuery = '';
  List<RegionModel> _regions = [];
  List<UserModel> _agents = [];
  List<UserModel> _members = [];
  Map<String, List<UserModel>> _regionAssignments = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RegionModel> get _filteredRegions {
    if (_searchQuery.isEmpty) return _regions;
    return _regions.where((region) {
      final supervisorMatches =
          _agents.where((a) => a.id == region.supervisorId).toList();
      final supervisorName =
          supervisorMatches.isNotEmpty
              ? (supervisorMatches.first.fullName ?? '')
              : '';
      final agentMatches =
          _agents.where((a) => a.id == region.assignedTo).toList();
      final agentName =
          agentMatches.isNotEmpty ? (agentMatches.first.fullName ?? '') : '';
      final haystack =
          [
            region.region,
            region.subRegion,
            region.counties ?? '',
            agentName,
            supervisorName,
          ].join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  int get _totalRegions => _regions.length;
  int get _assignedRegions =>
      _regions
          .where((r) => r.assignedTo != null && r.assignedTo!.isNotEmpty)
          .length;
  int get _unassignedRegions => _totalRegions - _assignedRegions;
  int get _totalMembers => _members.length;

  Future<Map<String, List<UserModel>>> _loadRegionAssignments() async {
    final result = <String, List<UserModel>>{};
    for (final region in _regions) {
      if (region.id == null) continue;
      final users = await _dbService.getRegionAssignments(region.id!);
      result[region.id!] = users;
    }
    return result;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final regions = await _dbService.getAllRegions();
    final users = await _dbService.getAllUsers();
    final agents = users.where((u) => u.role == 4).toList();
    final members = users.where((u) => u.role == 5).toList();
    final assignments = await _loadRegionAssignments();
    if (!mounted) return;
    setState(() {
      _regions = regions;
      _agents = agents;
      _members = members;
      _regionAssignments = assignments;
      _isLoading = false;
    });
  }

  Future<void> _showRegionForm({RegionModel? region}) async {
    final isEdit = region != null;
    final controllerRegion = TextEditingController(text: region?.region ?? '');
    final controllerSubRegion = TextEditingController(
      text: region?.subRegion ?? '',
    );
    final selectedCounties = <String>{};
    final existingCounties = region?.counties;
    if (existingCounties != null && existingCounties.isNotEmpty) {
      selectedCounties.addAll(
        existingCounties
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty),
      );
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 520 ? 520.0 : screenWidth - 32.0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickCounties() async {
              final pickerWidth =
                  screenWidth > 420 ? 420.0 : screenWidth - 32.0;
              final picked = await showDialog<Set<String>>(
                context: context,
                builder: (context) {
                  final tempSelected = Set<String>.from(selectedCounties);
                  return StatefulBuilder(
                    builder: (context, setPickedState) {
                      return AlertDialog(
                        title: const Text('Select Counties'),
                        content: SizedBox(
                          width: pickerWidth,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _kenyanCounties.length,
                            itemBuilder: (context, index) {
                              final county = _kenyanCounties[index];
                              final isChecked = tempSelected.contains(county);
                              return CheckboxListTile(
                                value: isChecked,
                                title: Text(county),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  setPickedState(() {
                                    if (value == true) {
                                      tempSelected.add(county);
                                    } else {
                                      tempSelected.remove(county);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedCounties.clear();
                                selectedCounties.addAll(tempSelected);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              if (picked != null) {
                setDialogState(() {
                  selectedCounties.clear();
                  selectedCounties.addAll(picked);
                });
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Region' : 'Add Region'),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controllerRegion,
                      decoration: const InputDecoration(
                        labelText: 'Region',
                        hintText: 'e.g. Coast',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controllerSubRegion,
                      decoration: const InputDecoration(
                        labelText: 'Sub Region',
                        hintText: 'e.g. Mombasa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickCounties,
                      icon: const Icon(Icons.location_on_outlined),
                      label: Text(
                        selectedCounties.isEmpty
                            ? 'Select Counties'
                            : '${selectedCounties.length} Counties Selected',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (isEdit)
                  TextButton(
                    onPressed: () async {
                      if (controllerRegion.text.trim().isEmpty ||
                          controllerSubRegion.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill in both region and sub region',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final updated = region.copyWith(
                        region: controllerRegion.text.trim(),
                        subRegion: controllerSubRegion.text.trim(),
                        counties: selectedCounties.join(', '),
                      );
                      final duplicate = _regions.any(
                        (r) =>
                            r.id != region.id &&
                            r.region.toLowerCase() ==
                                updated.region.toLowerCase() &&
                            r.subRegion.toLowerCase() ==
                                updated.subRegion.toLowerCase(),
                      );
                      if (duplicate) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'A region with this sub-region already exists.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      try {
                        await _dbService.updateRegion(updated);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Region updated'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Update'),
                  ),
                if (!isEdit)
                  ElevatedButton(
                    onPressed: () async {
                      if (controllerRegion.text.trim().isEmpty ||
                          controllerSubRegion.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill in both region and sub region',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final newRegion = RegionModel(
                        region: controllerRegion.text.trim(),
                        subRegion: controllerSubRegion.text.trim(),
                        counties: selectedCounties.join(', '),
                      );
                      final duplicate = _regions.any(
                        (r) =>
                            r.region.toLowerCase() ==
                                newRegion.region.toLowerCase() &&
                            r.subRegion.toLowerCase() ==
                                newRegion.subRegion.toLowerCase(),
                      );
                      if (duplicate) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'A region with this sub-region already exists.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      try {
                        await _dbService.createRegion(newRegion);
                        if (!mounted) return;
                        Navigator.pop(context);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Region created'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Create'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignSupervisorDialog(RegionModel region) async {
    final availableSupervisors = _agents.where((u) => u.role == 3).toList();
    if (availableSupervisors.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No supervisors available. Create a Role 3 user first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final assignmentsByUser = <String, Set<String>>{};
    for (final entry in _regionAssignments.entries) {
      for (final user in entry.value) {
        assignmentsByUser.putIfAbsent(user.id, () => <String>{}).add(entry.key);
      }
    }
    final currentIds = Set<String>.from(
      (_regionAssignments[region.id ?? ''] ?? [])
          .where((u) => u.role == 3)
          .map((u) => u.id),
    );
    final currentRegionIds = Set<String>.from(
      _regions
          .where((r) => r.id != null && r.id!.isNotEmpty)
          .map((r) => r.id!)
          .toList(),
    );
    final selected = Set<String>.from(currentIds);
    final selectedRegions = <String>{region.id ?? ''};

    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 520 ? 520.0 : screenWidth - 32.0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Supervisors to Regions'),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableSupervisors.length,
                        itemBuilder: (context, index) {
                          final supervisor = availableSupervisors[index];
                          final isSelected = selected.contains(supervisor.id);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.remove(supervisor.id);
                                } else {
                                  selected.add(supervisor.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selected.add(supervisor.id);
                                        } else {
                                          selected.remove(supervisor.id);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      supervisor.fullName ?? supervisor.email,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Regions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _regions.length,
                        itemBuilder: (context, index) {
                          final r = _regions[index];
                          if (r.id == null) return const SizedBox.shrink();
                          final isChecked = selectedRegions.contains(r.id);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isChecked) {
                                  selectedRegions.remove(r.id!);
                                } else {
                                  selectedRegions.add(r.id!);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedRegions.add(r.id!);
                                        } else {
                                          selectedRegions.remove(r.id!);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      r.subRegion,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final safeRegions =
                        selectedRegions
                            .where((id) => currentRegionIds.contains(id))
                            .toList();
                    for (final regionId in safeRegions) {
                      for (final supervisor in availableSupervisors) {
                        final wasAssigned = (assignmentsByUser[supervisor.id] ??
                                {})
                            .contains(regionId);
                        final shouldBeAssigned = selected.contains(
                          supervisor.id,
                        );
                        if (shouldBeAssigned && !wasAssigned) {
                          await _dbService.assignUserToRegion(
                            regionId,
                            supervisor.id,
                            3,
                          );
                        } else if (!shouldBeAssigned && wasAssigned) {
                          await _dbService.unassignUserFromRegion(
                            regionId,
                            supervisor.id,
                          );
                        }
                      }
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Supervisors updated'),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignAgentDialog(RegionModel region) async {
    final availableAgents = _agents.where((u) => u.role == 4).toList();
    if (availableAgents.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No agents available. Create a Role 4 user first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final assignmentsByUser = <String, Set<String>>{};
    for (final entry in _regionAssignments.entries) {
      for (final user in entry.value) {
        assignmentsByUser.putIfAbsent(user.id, () => <String>{}).add(entry.key);
      }
    }
    final currentIds = Set<String>.from(
      (_regionAssignments[region.id ?? ''] ?? [])
          .where((u) => u.role == 4)
          .map((u) => u.id),
    );
    final currentRegionIds = Set<String>.from(
      _regions
          .where((r) => r.id != null && r.id!.isNotEmpty)
          .map((r) => r.id!)
          .toList(),
    );
    final selected = Set<String>.from(currentIds);
    final selectedRegions = <String>{region.id ?? ''};

    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 520 ? 520.0 : screenWidth - 32.0;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Agents to Regions'),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableAgents.length,
                        itemBuilder: (context, index) {
                          final agent = availableAgents[index];
                          final isSelected = selected.contains(agent.id);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.remove(agent.id);
                                } else {
                                  selected.add(agent.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selected.add(agent.id);
                                        } else {
                                          selected.remove(agent.id);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      agent.fullName ?? agent.email,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Regions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _regions.length,
                        itemBuilder: (context, index) {
                          final r = _regions[index];
                          if (r.id == null) return const SizedBox.shrink();
                          final isChecked = selectedRegions.contains(r.id);
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isChecked) {
                                  selectedRegions.remove(r.id!);
                                } else {
                                  selectedRegions.add(r.id!);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isChecked,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedRegions.add(r.id!);
                                        } else {
                                          selectedRegions.remove(r.id!);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      r.subRegion,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final safeRegions =
                        selectedRegions
                            .where((id) => currentRegionIds.contains(id))
                            .toList();
                    for (final regionId in safeRegions) {
                      for (final agent in availableAgents) {
                        final wasAssigned = (assignmentsByUser[agent.id] ?? {})
                            .contains(regionId);
                        final shouldBeAssigned = selected.contains(agent.id);
                        if (shouldBeAssigned && !wasAssigned) {
                          await _dbService.assignUserToRegion(
                            regionId,
                            agent.id,
                            4,
                          );
                        } else if (!shouldBeAssigned && wasAssigned) {
                          await _dbService.unassignUserFromRegion(
                            regionId,
                            agent.id,
                          );
                        }
                      }
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Agents updated'),
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    );
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddMemberDialog(RegionModel region) async {
    final availableMembers = _members;

    await showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 520 ? 520.0 : screenWidth - 32.0;

        return AlertDialog(
          title: Text('Add Member to ${region.subRegion}'),
          content: SizedBox(
            width: dialogWidth,
            child:
                availableMembers.isEmpty
                    ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text('No available members for this region.'),
                      ),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableMembers.length,
                      itemBuilder: (context, index) {
                        final member = availableMembers[index];
                        return _MemberTile(
                          member: member,
                          region: region,
                          onAdd: () async {
                            await _dbService.addMemberToRegion(
                              region.id!,
                              member.id,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${member.fullName ?? member.email} added to ${region.subRegion}',
                                ),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                          onPromote: (role) async {
                            await _dbService.promoteRegionMemberToAgent(
                              region.id!,
                              member.id,
                              role: role,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${member.fullName ?? member.email} promoted to role $role in ${region.subRegion}',
                                ),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRegion(RegionModel region) async {
    if (region.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Region'),
            content: Text('Delete ${region.subRegion}? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await _dbService.deleteRegion(region.id!);
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${region.subRegion} deleted'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting region: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _countyChipColor(String county) {
    final map = <String, Color>{
      'Nairobi': Colors.blue,
      'Mombasa': Colors.teal,
      'Kisumu': Colors.orange,
      'Nakuru': Colors.purple,
      'Kiambu': Colors.indigo,
    };
    return map[county] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regions Management'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                _StatCard(
                                  label: 'Regions',
                                  value: '$_totalRegions',
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  label: 'Assigned',
                                  value: '$_assignedRegions',
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  label: 'Unassigned',
                                  value: '$_unassignedRegions',
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  label: 'Members',
                                  value: '$_totalMembers',
                                  color: Colors.indigo,
                                ),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search regions, counties, or agent...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    _searchQuery.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                        : null,
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    _filteredRegions.isEmpty
                        ? SliverFillRemaining(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 72,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No regions yet'
                                        : 'No results for "$_searchQuery"',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'Create your first region to start assigning agents.'
                                        : 'Try adjusting your search.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final region = _filteredRegions[index];
                              final assignedUsers =
                                  _regionAssignments[region.id ?? ''] ?? [];
                              final assignedAgents =
                                  assignedUsers
                                      .where((u) => u.role == 4)
                                      .toList();
                              final assignedSupervisors =
                                  assignedUsers
                                      .where((u) => u.role == 3)
                                      .toList();
                              final legacyAssignedUser =
                                  region.assignedTo == null
                                      ? null
                                      : _agents.cast<UserModel?>().firstWhere(
                                        (a) =>
                                            a != null &&
                                            a.id == region.assignedTo,
                                        orElse: () => null,
                                      );
                              final legacySupervisorUser =
                                  region.supervisorId == null
                                      ? null
                                      : _agents.cast<UserModel?>().firstWhere(
                                        (a) =>
                                            a != null &&
                                            a.id == region.supervisorId,
                                        orElse: () => null,
                                      );
                              final displayAgents =
                                  assignedAgents.isEmpty &&
                                          legacyAssignedUser != null
                                      ? [legacyAssignedUser]
                                      : assignedAgents;
                              final displaySupervisors =
                                  assignedSupervisors.isEmpty &&
                                          legacySupervisorUser != null
                                      ? [legacySupervisorUser]
                                      : assignedSupervisors;
                              return _RegionCard(
                                region: region,
                                assignedAgents: displayAgents,
                                assignedSupervisors: displaySupervisors,
                                countyColor: _countyChipColor,
                                onEdit: () => _showRegionForm(region: region),
                                onDelete: () => _deleteRegion(region),
                                onAssignAgent:
                                    () => _showAssignAgentDialog(region),
                                onAssignSupervisor:
                                    () => _showAssignSupervisorDialog(region),
                                onMembers: () => _showAddMemberDialog(region),
                              );
                            }, childCount: _filteredRegions.length),
                          ),
                        ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRegionForm(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Region'),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final RegionModel region;
  final List<UserModel> assignedAgents;
  final List<UserModel> assignedSupervisors;
  final Color Function(String) countyColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssignAgent;
  final VoidCallback onAssignSupervisor;
  final VoidCallback onMembers;

  const _RegionCard({
    required this.region,
    required this.assignedAgents,
    required this.assignedSupervisors,
    required this.countyColor,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignAgent,
    required this.onAssignSupervisor,
    required this.onMembers,
  });

  List<String> get _counties {
    if (region.counties == null || region.counties!.isEmpty) return const [];
    return region.counties!
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
  }

  bool get hasSupervisors => assignedSupervisors.isNotEmpty;
  bool get hasAgents => assignedAgents.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final counties = _counties;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primaryDark,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.subRegion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        region.region,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (hasSupervisors)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Has Supervisor',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            hasAgents
                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        hasAgents ? 'Assigned' : 'Unassigned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              hasAgents
                                  ? AppColors.primaryGreen
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (counties.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    counties
                        .map(
                          (county) => Chip(
                            label: Text(
                              county,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: countyColor(
                              county,
                            ).withValues(alpha: 0.1),
                            side: BorderSide(
                              color: countyColor(county).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
            if (assignedSupervisors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.supervisor_account_outlined,
                      size: 20,
                      color: Colors.purple.shade600,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            assignedSupervisors.map((user) {
                              final displayName =
                                  (user.fullName ?? '').trim().isNotEmpty
                                      ? user.fullName!
                                      : user.email;
                              return Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.purple.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    hasAgents
                        ? Icons.person_outline_rounded
                        : Icons.person_off_outlined,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final displayNames =
                            assignedAgents.map((user) {
                              final displayName =
                                  (user.fullName ?? '').trim().isNotEmpty
                                      ? user.fullName!
                                      : user.email;
                              return displayName;
                            }).toList();
                        final text =
                            displayNames.isEmpty
                                ? 'No agents assigned'
                                : displayNames.join(', ');
                        return Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                hasAgents
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade500,
                            fontWeight:
                                hasAgents ? FontWeight.w500 : FontWeight.normal,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onAssignSupervisor,
                        icon: const Icon(
                          Icons.supervisor_account_outlined,
                          size: 18,
                        ),
                        label: const Text('Supervisors'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onAssignAgent,
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 18,
                        ),
                        label: const Text('Agents'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onMembers,
                        icon: const Icon(Icons.group_outlined, size: 18),
                        label: const Text('Members'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.08),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.08),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UserModel member;
  final RegionModel region;
  final VoidCallback onAdd;
  final ValueChanged<int> onPromote;

  const _MemberTile({
    required this.member,
    required this.region,
    required this.onAdd,
    required this.onPromote,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        (member.fullName ?? '').trim().isEmpty
            ? member.email
            : member.fullName!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 380;

        if (isWide) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ActionButton(label: 'Add', onPressed: onAdd),
                const SizedBox(width: 8),
                _PromoteDropdown(onPromote: onPromote),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          member.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(label: 'Add', onPressed: onAdd),
                  _PromoteDropdown(onPromote: onPromote),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PromoteDropdown extends StatelessWidget {
  final ValueChanged<int> onPromote;

  const _PromoteDropdown({required this.onPromote});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            hint: const Text('Promote to'),
            items: const [
              DropdownMenuItem(value: 3, child: Text('Supervisor')),
              DropdownMenuItem(value: 4, child: Text('Agent')),
            ],
            onChanged: (value) {
              if (value != null) onPromote(value);
            },
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );

    if (!isPrimary) return button;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }
}
