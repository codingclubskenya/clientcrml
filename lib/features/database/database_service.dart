import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../models/farmer_model.dart';
import '../../models/message_model.dart';
import '../../models/catalog_item_model.dart';
import '../../models/order_item_model.dart';
import '../../models/order_model.dart';
import '../../models/school_sale_model.dart';
import '../../models/region_model.dart';
import '../../models/pipeline_stage.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DatabaseService {
  static Future<Box<dynamic>>? _schoolBoxFuture;
  static Future<Box<dynamic>>? _catalogBoxFuture;
  static Future<Box<dynamic>>? _pendingOpsBoxFuture;
  static Future<Box<dynamic>>? _reportsCacheBoxFuture;
  final Future<List<ConnectivityResult>> Function()? _connectivityCheck;
  final Future<Box<dynamic>> Function()? _schoolBoxProvider;
  final Future<Box<dynamic>> Function()? _catalogBoxProvider;
  final Future<Box<dynamic>> Function()? _pendingOpsBoxProvider;
  final Future<Box<dynamic>> Function()? _reportsCacheBoxProvider;
  final Future<void> Function(Map<String, dynamic>)? _upsertSchoolOverride;
  final Future<void> Function(SchoolModel)? _syncEngagementOverride;
  final Future<void> Function(Map<String, dynamic>)? _upsertCatalogOverride;
  final Future<int> Function()? _currentUserRoleOverride;

  DatabaseService({
    Future<List<ConnectivityResult>> Function()? connectivityCheck,
    Future<Box<dynamic>> Function()? schoolBoxProvider,
    Future<Box<dynamic>> Function()? catalogBoxProvider,
    Future<Box<dynamic>> Function()? pendingOpsBoxProvider,
    Future<Box<dynamic>> Function()? reportsCacheBoxProvider,
    Future<void> Function(Map<String, dynamic>)? upsertSchoolOverride,
    Future<void> Function(SchoolModel)? syncEngagementOverride,
    Future<void> Function(Map<String, dynamic>)? upsertCatalogOverride,
    Future<int> Function()? currentUserRoleOverride,
  }) : _connectivityCheck = connectivityCheck,
       _schoolBoxProvider = schoolBoxProvider,
       _catalogBoxProvider = catalogBoxProvider,
       _pendingOpsBoxProvider = pendingOpsBoxProvider,
       _reportsCacheBoxProvider = reportsCacheBoxProvider,
       _upsertSchoolOverride = upsertSchoolOverride,
       _syncEngagementOverride = syncEngagementOverride,
       _upsertCatalogOverride = upsertCatalogOverride,
       _currentUserRoleOverride = currentUserRoleOverride;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Box<dynamic>> get _box async {
    if (_schoolBoxProvider != null) return _schoolBoxProvider();
    _schoolBoxFuture ??= Hive.openBox('school_box');
    return _schoolBoxFuture!;
  }

  Future<Box<dynamic>> get _catalogBox async {
    if (_catalogBoxProvider != null) return _catalogBoxProvider();
    _catalogBoxFuture ??= Hive.openBox('catalog_box');
    return _catalogBoxFuture!;
  }

  Future<Box<dynamic>> get _pendingOpsBox async {
    if (_pendingOpsBoxProvider != null) return _pendingOpsBoxProvider();
    _pendingOpsBoxFuture ??= Hive.openBox('pending_ops_box');
    return _pendingOpsBoxFuture!;
  }

  Future<Box<dynamic>> get _reportsCacheBox async {
    if (_reportsCacheBoxProvider != null) return _reportsCacheBoxProvider();
    _reportsCacheBoxFuture ??= Hive.openBox('reports_cache_box');
    return _reportsCacheBoxFuture!;
  }

  Future<void> cacheReport(String key, Map<String, dynamic> report) async {
    try {
      final box = await _reportsCacheBox;
      await box.put(key, {
        'report': report,
        'cached_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error caching report: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedReport(String key) async {
    try {
      final box = await _reportsCacheBox;
      final entry = box.get(key);
      if (entry is Map) {
        final cachedAt = DateTime.tryParse(
          entry['cached_at']?.toString() ?? '',
        );
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt).inHours < 24) {
          return Map<String, dynamic>.from(entry['report'] ?? {});
        }
        await box.delete(key);
      }
    } catch (e) {
      debugPrint('Error reading cached report: $e');
    }
    return null;
  }

  // User management methods
  Future<void> saveUser(UserModel user) async {
    try {
      await _supabase.from('users').upsert(user.toMap());
      debugPrint("User ${user.email} saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving user to Supabase: $e");
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final data =
          await _supabase.from('users').select().eq('id', uid).maybeSingle();
      if (data != null) {
        return UserModel.fromMap(data);
      }
    } catch (e) {
      debugPrint("Error getting user from Supabase: $e");
    }
    return null;
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final data = await _supabase.from('users').select().order('created_at');
      return (data as List)
          .map((item) => UserModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting users from Supabase: $e");
      return <UserModel>[];
    }
  }

  Future<void> updateUserRole(String uid, int role) async {
    try {
      await _supabase.from('users').update({'role': role}).eq('id', uid);
      debugPrint("User $uid role updated to $role.");
    } catch (e) {
      debugPrint("Error updating user role: $e");
      rethrow;
    }
  }

  Future<List<RegionModel>> getAllRegions() async {
    try {
      final data = await _supabase
          .from('regions')
          .select()
          .order('region')
          .order('sub_region');
      return (data as List)
          .map((item) => RegionModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting regions: $e");
      return <RegionModel>[];
    }
  }

  Future<List<String>> getDistinctTargetScopes() async {
    return const ['regional', 'agent', 'business_advisor', 'sales_rep'];
  }

  Future<List<String>> getDistinctTargetTypes() async {
    return const [
      'product_sales',
      'customer_visits',
      'collections',
      'new_customers',
      'sample_distribution',
      'consignment',
    ];
  }

  Future<List<String>> getDistinctTargetPeriods() async {
    return const ['daily', 'weekly', 'monthly', 'quarterly', 'yearly', 'ytd'];
  }

  Future<List<String>> getDistinctSubRegions() async {
    try {
      final data = await _supabase
          .from('targets')
          .select('sub_region')
          .not('sub_region', 'is', null);
      return (data as List)
          .map((item) => item['sub_region']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      debugPrint('Error getting sub regions: $e');
      return <String>[];
    }
  }

  Future<List<Map<String, String>>> getAssignableUsersByRoles(
    List<int> roles,
  ) async {
    try {
      final data = await _supabase
          .from('users')
          .select('id, full_name, email, role');
      final roleSet = roles.toSet();
      return (data as List)
          .where((item) => roleSet.contains((item['role'] as int?) ?? 5))
          .map(
            (item) => {
              'id': item['id']?.toString() ?? '',
              'label':
                  '${item['full_name']?.toString() ?? item['email']?.toString() ?? 'Unknown'} (${_roleLabel(item['role'] ?? 5)})',
              'role': item['role']?.toString() ?? '5',
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting assignable users: $e');
      return <Map<String, String>>[];
    }
  }

  Future<List<Map<String, String>>> getRegionOptions() async {
    try {
      final data = await _supabase
          .from('regions')
          .select('id, region, sub_region')
          .order('region')
          .order('sub_region');
      return (data as List)
          .map(
            (item) => {
              'id': item['id']?.toString() ?? '',
              'label': '${item['region']} - ${item['sub_region']}',
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting region options: $e');
      return <Map<String, String>>[];
    }
  }

  static String _roleLabel(int role) {
    switch (role) {
      case 1:
        return 'Admin';
      case 2:
        return 'Manager';
      case 3:
        return 'BAS';
      case 4:
        return 'Agent';
      case 5:
        return 'Sales Rep';
      default:
        return 'User';
    }
  }

  Future<RegionModel?> getRegion(String id) async {
    try {
      final data =
          await _supabase.from('regions').select().eq('id', id).maybeSingle();
      if (data != null) {
        return RegionModel.fromMap(data);
      }
    } catch (e) {
      debugPrint("Error getting region: $e");
    }
    return null;
  }

  Future<void> createRegion(RegionModel region) async {
    try {
      await _supabase.from('regions').insert(region.toMap());
      debugPrint("Region created: ${region.region} - ${region.subRegion}");
    } catch (e) {
      debugPrint("Error creating region: $e");
      rethrow;
    }
  }

  Future<void> updateRegion(RegionModel region) async {
    try {
      await _supabase
          .from('regions')
          .update(region.toMap())
          .eq('id', region.id!);
      debugPrint("Region updated: ${region.region} - ${region.subRegion}");
    } catch (e) {
      debugPrint("Error updating region: $e");
      rethrow;
    }
  }

  Future<void> deleteRegion(String id) async {
    try {
      await _supabase.from('region_assignments').delete().eq('region_id', id);
      final region = await getRegion(id);
      await _supabase.from('regions').delete().eq('id', id);
      if (region != null) {
        await _supabase
            .from('users')
            .update({'region': null, 'region_id': null})
            .eq('region_id', id);
        final regionName = region.region;
        if (regionName.isNotEmpty) {
          await _supabase
              .from('users')
              .update({'region': null})
              .or('region.eq.$regionName,sub_region.eq.${region.subRegion}');
        }
      }
      debugPrint("Region deleted: $id");
    } catch (e) {
      debugPrint("Error deleting region: $e");
      rethrow;
    }
  }

  Future<void> assignRegionToAgent(String regionId, String agentId) async {
    try {
      final region = await getRegion(regionId);
      if (region == null) {
        throw Exception('Region not found');
      }
      await _supabase
          .from('regions')
          .update({'assigned_to': agentId})
          .eq('id', regionId);
      await _supabase
          .from('users')
          .update({
            'role_ref': 'agent',
            'region': region.region,
            'region_id': regionId,
          })
          .eq('id', agentId);
      try {
        await _supabase.from('region_assignments').insert({
          'region_id': regionId,
          'user_id': agentId,
          'role': 4,
        });
      } catch (e) {
        debugPrint('region_assignments insert failed: $e');
        throw Exception(
          'Legacy assignment succeeded, but multi-region assignment failed: $e',
        );
      }
      debugPrint("Region $regionId assigned to agent $agentId");
    } catch (e) {
      debugPrint("Error assigning region to agent: $e");
      rethrow;
    }
  }

  Future<void> assignRegionSupervisor(
    String regionId,
    String supervisorId,
  ) async {
    try {
      final region = await getRegion(regionId);
      if (region == null) {
        throw Exception('Region not found');
      }
      await _supabase
          .from('regions')
          .update({'supervisor_id': supervisorId})
          .eq('id', regionId);
      await _supabase
          .from('users')
          .update({
            'role_ref': 'supervisor',
            'region': region.region,
            'region_id': regionId,
          })
          .eq('id', supervisorId);
      try {
        await _supabase.from('region_assignments').insert({
          'region_id': regionId,
          'user_id': supervisorId,
          'role': 3,
        });
      } catch (e) {
        debugPrint('region_assignments insert failed: $e');
        throw Exception(
          'Legacy assignment succeeded, but multi-region assignment failed: $e',
        );
      }
      debugPrint("Region $regionId assigned to supervisor $supervisorId");
    } catch (e) {
      debugPrint("Error assigning region to supervisor: $e");
      rethrow;
    }
  }

  Future<void> unassignRegionSupervisor(String regionId) async {
    try {
      final region = await getRegion(regionId);
      final previousSupervisorId = region?.supervisorId;
      await _supabase
          .from('regions')
          .update({'supervisor_id': null})
          .eq('id', regionId);
      if (previousSupervisorId != null) {
        await _supabase
            .from('users')
            .update({'region': null, 'region_id': null})
            .eq('id', previousSupervisorId);
      }
      try {
        await _supabase
            .from('region_assignments')
            .delete()
            .eq('region_id', regionId)
            .eq('role', 3);
      } catch (e) {
        debugPrint('region_assignments delete failed: $e');
        throw Exception(
          'Legacy unassignment succeeded, but multi-region cleanup failed: $e',
        );
      }
      debugPrint("Region $regionId unassigned from supervisor");
    } catch (e) {
      debugPrint("Error unassigning region from supervisor: $e");
      rethrow;
    }
  }

  Future<void> addMemberToRegion(String regionId, String memberId) async {
    try {
      final region = await getRegion(regionId);
      if (region == null) {
        throw Exception('Region not found');
      }
      await _supabase
          .from('users')
          .update({'region': region.region, 'region_id': regionId})
          .eq('id', memberId);
      debugPrint("Member $memberId added to region $regionId");
    } catch (e) {
      debugPrint("Error adding member to region: $e");
      rethrow;
    }
  }

  Future<void> promoteRegionMemberToAgent(
    String regionId,
    String memberId, {
    int role = 4,
  }) async {
    try {
      final region = await getRegion(regionId);
      if (region == null) {
        throw Exception('Region not found');
      }
      await _supabase
          .from('users')
          .update({
            'role': role,
            'region': region.region,
            'region_id': regionId,
          })
          .eq('id', memberId);
      debugPrint("Member $memberId promoted to role $role in region $regionId");
    } catch (e) {
      debugPrint("Error promoting member to agent: $e");
      rethrow;
    }
  }

  Future<void> unassignRegionFromAgent(String regionId) async {
    try {
      final region = await getRegion(regionId);
      final previousAgentId = region?.assignedTo;
      await _supabase
          .from('regions')
          .update({'assigned_to': null})
          .eq('id', regionId);
      if (previousAgentId != null) {
        await _supabase
            .from('users')
            .update({'region': null, 'region_id': null})
            .eq('id', previousAgentId);
      }
      try {
        await _supabase
            .from('region_assignments')
            .delete()
            .eq('region_id', regionId)
            .eq('role', 4);
      } catch (e) {
        debugPrint('region_assignments delete failed: $e');
        throw Exception(
          'Legacy unassignment succeeded, but multi-region cleanup failed: $e',
        );
      }
      debugPrint("Region $regionId unassigned from agent");
    } catch (e) {
      debugPrint("Error unassigning region from agent: $e");
      rethrow;
    }
  }

  Future<List<UserModel>> getRegionAssignments(String regionId) async {
    try {
      final data = await _supabase
          .from('region_assignments')
          .select('user_id, role')
          .eq('region_id', regionId);
      final userIds =
          (data as List)
              .map((e) => (e['user_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
      if (userIds.isEmpty) return <UserModel>[];
      final users = <UserModel>[];
      for (final id in userIds) {
        final user = await getUser(id);
        if (user != null) users.add(user);
      }
      return users;
    } catch (e) {
      debugPrint("Error getting region assignments: $e");
      return <UserModel>[];
    }
  }

  Future<void> assignUserToRegion(
    String regionId,
    String userId,
    int role,
  ) async {
    try {
      await _supabase.from('region_assignments').insert({
        'region_id': regionId,
        'user_id': userId,
        'role': role,
      });
      debugPrint("User $userId assigned to region $regionId as role $role");
    } catch (e) {
      debugPrint("Error assigning user to region: $e");
      rethrow;
    }
  }

  Future<void> unassignUserFromRegion(String regionId, String userId) async {
    try {
      await _supabase
          .from('region_assignments')
          .delete()
          .eq('region_id', regionId)
          .eq('user_id', userId);
      debugPrint("User $userId unassigned from region $regionId");
    } catch (e) {
      debugPrint("Error unassigning user from region: $e");
      rethrow;
    }
  }

  Future<void> addSupervisorToRegion(
    String regionId,
    String supervisorId,
  ) async {
    try {
      await _supabase.from('region_assignments').insert({
        'region_id': regionId,
        'user_id': supervisorId,
        'role': 3,
      });
      debugPrint("Supervisor $supervisorId added to region $regionId");
    } catch (e) {
      debugPrint("Error adding supervisor to region: $e");
      rethrow;
    }
  }

  Future<void> addAgentToRegion(String regionId, String agentId) async {
    try {
      await _supabase.from('region_assignments').insert({
        'region_id': regionId,
        'user_id': agentId,
        'role': 4,
      });
      debugPrint("Agent $agentId added to region $regionId");
    } catch (e) {
      debugPrint("Error adding agent to region: $e");
      rethrow;
    }
  }

  // 1. Save school contact or lead offline first
  Future<void> saveSchoolProfile(SchoolModel school) async {
    // Save to local Hive box immediately
    final box = await _box;
    await box.put(school.id, school.toMap());

    await syncData();
  }

  Future<void> _upsertSchoolToRemote(SchoolModel school) async {
    if (_upsertSchoolOverride != null) {
      await _upsertSchoolOverride(school.toMap());
      return;
    }
    await _supabase.from('schools').upsert(school.toMap());
  }

  Future<void> _syncSchoolEngagement(SchoolModel school) async {
    if (_syncEngagementOverride != null) {
      await _syncEngagementOverride(school);
      return;
    }
    await _syncEngagementToPipeline(school);
  }

  Future<bool> _canManageCatalogItems() async {
    final role =
        _currentUserRoleOverride != null
            ? await _currentUserRoleOverride()
            : await getCurrentUserRole();
    return role <= 3;
  }

  Future<SchoolSaveResult> saveSchoolProfileWithStatus(
    SchoolModel school,
  ) async {
    final box = await _box;
    await box.put(school.id, school.toMap());

    final connectivityResult =
        _connectivityCheck != null
            ? await _connectivityCheck()
            : await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return const SchoolSaveResult(
        syncedToDatabase: false,
        message: 'Saved locally. No internet connection.',
      );
    }

    try {
      await _upsertSchoolToRemote(school);
      await box.put(school.id, school.copyWithSynced(true).toMap());

      try {
        await _syncSchoolEngagement(school);
      } catch (e) {
        debugPrint(
          "School ${school.id} synced, but engagement sync failed: $e",
        );
        return SchoolSaveResult(
          syncedToDatabase: true,
          message:
              'Saved and synced to database, but CRM sync will retry later: $e',
        );
      }

      return const SchoolSaveResult(
        syncedToDatabase: true,
        message: 'Saved and synced to database.',
      );
    } catch (e) {
      return SchoolSaveResult(
        syncedToDatabase: false,
        message: 'Saved locally, but database sync failed: $e',
      );
    }
  }

  Future<bool> isSchoolSyncedRemotely(String schoolId) async {
    try {
      final row =
          await _supabase
              .from('schools')
              .select('id')
              .eq('id', schoolId)
              .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateSchoolProfile(SchoolModel school) async {
    final updatedSchool = SchoolModel(
      id: school.id,
      name: school.name,
      phone: school.phone,
      county: school.county,
      focusAreas: school.focusAreas,
      bookCategory: school.bookCategory,
      dealerType: school.dealerType,
      shopCategory: school.shopCategory,
      selectedProduct: school.selectedProduct,
      partnerSubtype: school.partnerSubtype,
      latitude: school.latitude,
      longitude: school.longitude,
      photoUrl: school.photoUrl,
      photoPath: school.photoPath,
      capturedBy: school.capturedBy,
      capturedAt: school.capturedAt,
      captureStatus: school.captureStatus,
      contactName: school.contactName,
      contactPhone: school.contactPhone,
      contactTitle: school.contactTitle,
      feedback: school.feedback,
      notes: school.notes,
      samplesLeft: school.samplesLeft,
      sampleBooks: school.sampleBooks,
      schoolOwnership: school.schoolOwnership,
      schoolOwnershipOther: school.schoolOwnershipOther,
      schoolPopulation: school.schoolPopulation,
      schoolLifecycleStatus: school.schoolLifecycleStatus,
      engagementType: school.engagementType,
      isSynced: false,
      createdAt: school.createdAt,
      updatedAt: DateTime.now(),
    );
    await saveSchoolProfile(updatedSchool);
  }

  Future<void> deleteSchoolProfile(String schoolId) async {
    final box = await _box;
    await box.delete(schoolId);
    try {
      await deleteByIdWithOfflineQueue(table: 'schools', id: schoolId);
    } catch (e) {
      debugPrint("Error deleting school $schoolId from Supabase: $e");
    }
  }

  // 2. Sync pending data to Supabase
  Future<void> syncData() async {
    final connectivityResult =
        _connectivityCheck != null
            ? await _connectivityCheck()
            : await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final box = await _box;
    final schools = box.values.map((e) => SchoolModel.fromMap(e)).toList();
    final unsynced = schools.where((f) => !f.isSynced).toList();

    for (var school in unsynced) {
      try {
        await _upsertSchoolToRemote(school);

        // Preserve all existing fields and only flip sync state after the
        // school row itself has been written successfully.
        final updatedSchool = school.copyWithSynced(true);
        await box.put(school.id, updatedSchool.toMap());

        try {
          await _syncSchoolEngagement(school);
        } catch (e) {
          debugPrint(
            "Pipeline sync failed for ${school.id}, but school row is synced: $e",
          );
        }
      } catch (e) {
        debugPrint("Sync Error for ${school.id}: $e");
      }
    }

    final canManageCatalogItems = await _canManageCatalogItems();

    // Sync Books (Catalog Items)
    if (canManageCatalogItems) {
      final catalogBox = await _catalogBox;
      final catalogs =
          catalogBox.values
              .map(
                (e) => CatalogItemModel.fromMap(Map<String, dynamic>.from(e)),
              )
              .toList();
      final unsyncedCatalogs = catalogs.where((c) => !c.isSynced).toList();

      for (var catalog in unsyncedCatalogs) {
        try {
          if (_upsertCatalogOverride != null) {
            await _upsertCatalogOverride(catalog.toMap());
          } else {
            await _supabase
                .from('catalog_items')
                .upsert(catalog.toMap(), onConflict: 'sku');
          }

          // Update local status to synced
          final updatedCatalog = CatalogItemModel(
            id: catalog.id,
            name: catalog.name,
            category: catalog.category,
            sku: catalog.sku,
            itemType: catalog.itemType,
            unitPrice: catalog.unitPrice,
            stockQty: catalog.stockQty,
            description: catalog.description,
            isActive: catalog.isActive,
            isSynced: true,
          );
          await catalogBox.put(catalog.sku, updatedCatalog.toMap());
        } catch (e) {
          debugPrint("Sync Error for Catalog ${catalog.sku}: $e");
        }
      }
    } else {
      debugPrint(
        'Skipping catalog sync because the current user does not have catalog write access.',
      );
    }

    await _syncPendingOps();
  }

  // 3. Get all school contacts for UI
  Future<List<SchoolModel>> getAllSchoolProfiles() async {
    final box = await _box;
    return box.values.map((e) => SchoolModel.fromMap(e)).toList();
  }

  Future<List<SchoolModel>> getAllSchools() async {
    // Attempt a sync before read so UI reflects latest server state.
    try {
      await syncData();
    } catch (e) {
      debugPrint("Pre-fetch sync failed: $e");
    }

    final localSchools = await getAllSchoolProfiles();
    try {
      final data = await _supabase.from('schools').select().order('created_at');
      final remoteSchools =
          (data as List)
              .map(
                (item) => SchoolModel.fromMap(
                  Map<String, dynamic>.from(item),
                ).copyWithSynced(true),
              )
              .toList();

      final merged = <String, SchoolModel>{
        for (final school in localSchools) school.id: school,
        for (final school in remoteSchools) school.id: school,
      };

      return merged.values.toList();
    } catch (e) {
      debugPrint("Error getting schools from Supabase: $e");
      return localSchools;
    }
  }

  Future<List<SchoolModel>> getMySchools() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return <SchoolModel>[];

    try {
      await syncData();
    } catch (e) {
      debugPrint("Pre-fetch sync failed: $e");
    }

    final localSchools = await getAllSchoolProfiles();
    final myLocalSchools =
        localSchools.where((s) => s.capturedBy == currentUserId).toList();

    try {
      final data = await _supabase
          .from('schools')
          .select()
          .eq('captured_by', currentUserId)
          .order('created_at');
      final remoteSchools =
          (data as List)
              .map(
                (item) => SchoolModel.fromMap(
                  Map<String, dynamic>.from(item),
                ).copyWithSynced(true),
              )
              .toList();

      final merged = <String, SchoolModel>{
        for (final school in myLocalSchools) school.id: school,
        for (final school in remoteSchools) school.id: school,
      };

      return merged.values.toList();
    } catch (e) {
      debugPrint("Error getting my schools from Supabase: $e");
      return myLocalSchools;
    }
  }

  Future<List<TaskModel>> getAllTasks() async {
    try {
      final data = await _supabase
          .from('tasks')
          .select()
          .order('created_at', ascending: false);
      return (data as List)
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting tasks from Supabase: $e");
      return <TaskModel>[];
    }
  }

  Future<List<TaskModel>> getTasksForRole(int role) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return <TaskModel>[];

      final data = await _supabase
          .from('tasks')
          .select()
          .or('target_role.eq.$role,assigned_to.eq.$currentUserId')
          .order('created_at', ascending: false);
      return (data as List)
          .map((item) => TaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting tasks for role $role from Supabase: $e");
      return <TaskModel>[];
    }
  }

  Future<Map<String, double>> getTargetsForCurrentUser({
    required String period,
    String? targetType,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return {};

    try {
      final periodMap = {
        'daily': 'daily',
        'weekly': 'weekly',
        'monthly': 'monthly',
        'yearly': 'yearly',
      };
      final dbPeriod = periodMap[period] ?? period;

      var query = _supabase
          .from('targets')
          .select('target_type, target_period, target_data')
          .or('assigned_to.eq.$currentUserId,assigned_to.is.null')
          .eq('target_period', dbPeriod);

      if (targetType != null) {
        query = query.eq('target_type', targetType);
      }

      final data = await query;
      final targets = <String, double>{};

      for (final item in data as List) {
        final type = (item['target_type'] ?? '').toString();
        final targetData = item['target_data'];
        if (targetData is! Map) continue;

        double value = 0.0;
        final product = targetData['product'];
        final total = targetData['total'];
        if (product is num)
          value = product.toDouble();
        else if (total is num)
          value = total.toDouble();
        else if (product is String)
          value = double.tryParse(product) ?? 0.0;
        else if (total is String)
          value = double.tryParse(total) ?? 0.0;

        if (targetType != null) {
          targets[targetType] = value;
        } else {
          targets[type] = value;
        }
      }

      return targets;
    } catch (e) {
      debugPrint("Error loading targets: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> getPerformanceMetrics({
    required String period,
    int? role,
  }) async {
    final now = DateTime.now();
    final start =
        period == 'daily'
            ? DateTime(now.year, now.month, now.day)
            : period == 'weekly'
            ? now.subtract(const Duration(days: 7))
            : period == 'monthly'
            ? DateTime(now.year, now.month, 1)
            : DateTime(now.year, 1, 1);
    final target = await getTargetsForCurrentUser(period: period);
    final targetValue = target['product_sales'] ?? target['total'] ?? 0.0;
    final currentUserId = _supabase.auth.currentUser?.id;
    final agentId = role == 1 ? null : currentUserId;
    // Align the window to UTC so it matches the database's stored
    // timestamptz (created_at / visited_at) regardless of device timezone.
    final startIso = start.toUtc().toIso8601String();
    final nowIso = now.toUtc().toIso8601String();

    Future<int> countRows(
      String table,
      String dateColumn, {
      String? status,
      String? statusColumn,
    }) async {
      var query = _supabase.from(table).select('id');
      if (agentId != null) {
        query = query.eq('agent_id', agentId);
      }
      query = query.gte(dateColumn, startIso).lte(dateColumn, nowIso);
      if (status != null) {
        query = query.eq(statusColumn ?? 'status', status);
      }
      final response = await query;
      return (response as List).length;
    }

    Future<int> sumRows(
      String table,
      String dateColumn, {
      required String valueColumn,
    }) async {
      var query = _supabase.from(table).select('id, $valueColumn');
      if (agentId != null) {
        query = query.eq('agent_id', agentId);
      }
      query = query.gte(dateColumn, startIso).lte(dateColumn, nowIso);
      final response = await query;
      return (response as List).fold<int>(0, (sum, row) {
        final value = row[valueColumn];
        if (value is num) return sum + value.toInt();
        return sum;
      });
    }

    Future<int> countVisitedSchools() async {
      var query = _supabase.from('school_visits').select('school_id');
      if (agentId != null) {
        query = query.eq('agent_id', agentId);
      }
      query = query.gte('visited_at', startIso).lte('visited_at', nowIso);
      final response = await query;
      return (response as List)
          .map((row) => row['school_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;
    }

    final visits = await countRows('school_visits', 'visited_at');
    final orders = await countRows(
      'orders',
      'created_at',
      status: 'paid',
      statusColumn: 'status',
    );
    final wonSales = await countRows(
      'school_sales',
      'created_at',
      status: 'won',
      statusColumn: 'sale_status',
    );
    final samples = await sumRows(
      'school_sample_distributions',
      'distributed_at',
      valueColumn: 'quantity',
    );
    final sampleReturns = await sumRows(
      'school_sample_distributions',
      'distributed_at',
      valueColumn: 'returned_qty',
    );
    final visitedSchools = await countVisitedSchools();
    final percent =
        visits == 0 ? 0 : ((visits / targetValue) * 100).clamp(0, 100).round();

    return {
      'period': period,
      'percent': percent,
      'target': targetValue.round(),
      'visits': visits,
      'orders': orders,
      'wonSales': wonSales,
      'visitedSchools': visitedSchools,
      'samples': samples,
      'sampleReturns': sampleReturns,
    };
  }

  Future<Map<String, dynamic>> getIndividualPerformance({
    required String agentId,
    required DateTime start,
    required DateTime end,
    double dailyTarget = 15.0,
  }) async {
    // Align the window to UTC so it matches the database's stored
    // timestamptz (created_at / visited_at) regardless of device timezone.
    final startIso = start.toUtc().toIso8601String();
    final nowIso = end.toUtc().toIso8601String();

    Future<int> countRows(
      String table,
      String dateColumn, {
      String? status,
      String? statusColumn,
    }) async {
      var query = _supabase.from(table).select('id').eq('agent_id', agentId);
      query = query.gte(dateColumn, startIso).lte(dateColumn, nowIso);
      if (status != null) {
        query = query.eq(statusColumn ?? 'status', status);
      }
      final response = await query;
      return (response as List).length;
    }

    String classifySchoolType(Map<String, dynamic> school) {
      final buffer = [
            school['dealer_type'],
            school['shop_category'],
            school['school_level'],
            school['partner_subtype'],
            school['name'],
          ]
          .where((value) => value != null)
          .map((value) => value.toString().toLowerCase())
          .join(' ');

      if (buffer.contains('bookshop') ||
          buffer.contains('book shop') ||
          buffer.contains('bookstore') ||
          buffer.contains('book store')) {
        return 'bookshop';
      }

      if (buffer.contains('institution') ||
          buffer.contains('distributor') ||
          buffer.contains('dealer') ||
          buffer.contains('retail') ||
          buffer.contains('stockist')) {
        return 'institution';
      }

      return 'school';
    }

    final visitsFuture =
        (() async {
          final response = await _supabase
              .from('school_visits')
              .select('school_id')
              .eq('agent_id', agentId)
              .gte('visited_at', startIso)
              .lte('visited_at', nowIso);
          return List<Map<String, dynamic>>.from(response as List<dynamic>);
        })();
    final onboardedFuture =
        (() async {
          final response = await _supabase
              .from('schools')
              .select(
                'id, dealer_type, shop_category, school_level, partner_subtype, name',
              )
              .eq('captured_by', agentId)
              .gte('captured_at', startIso)
              .lte('captured_at', nowIso);
          return List<Map<String, dynamic>>.from(response as List<dynamic>);
        })();

    final results = await Future.wait<dynamic>([
      visitsFuture,
      onboardedFuture,
      countRows('orders', 'created_at', status: 'paid', statusColumn: 'status'),
      countRows(
        'school_sales',
        'created_at',
        status: 'won',
        statusColumn: 'sale_status',
      ),
    ]);

    final visitRows = List<Map<String, dynamic>>.from(
      results[0] as List<dynamic>,
    );
    final onboardedSchools = List<Map<String, dynamic>>.from(
      results[1] as List<dynamic>,
    );
    final orders = results[2] as int;
    final wonSales = results[3] as int;

    final schoolIds =
        visitRows
            .map((row) => row['school_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    final onboardedIds =
        onboardedSchools
            .map((row) => row['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    final allIds = {...schoolIds, ...onboardedIds}.toList();

    final counts = <String, int>{'school': 0, 'institution': 0, 'bookshop': 0};
    final visitedSchools = <String>{...schoolIds, ...onboardedIds}.length;

    if (allIds.isNotEmpty) {
      final schoolTypeRows =
          (await _supabase
                  .from('schools')
                  .select(
                    'id, dealer_type, shop_category, school_level, partner_subtype, name',
                  )
                  .inFilter('id', allIds))
              as List<dynamic>;
      final schoolTypeById = <String, String>{};
      for (final row in schoolTypeRows) {
        final school = Map<String, dynamic>.from(row as Map);
        final id = school['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        schoolTypeById[id] = classifySchoolType(school);
      }

      for (final row in visitRows) {
        final schoolId = row['school_id']?.toString() ?? '';
        final type = schoolTypeById[schoolId];
        if (type != null) {
          counts[type] = counts[type]! + 1;
        }
      }

      for (final id in onboardedIds) {
        final type = schoolTypeById[id];
        if (type != null) {
          counts[type] = counts[type]! + 1;
        }
      }
    }

    final visits = visitRows.length + onboardedIds.length;
    final schools = counts['school'] ?? 0;
    final institutions = counts['institution'] ?? 0;
    final bookshops = counts['bookshop'] ?? 0;
    final percent =
        visits == 0 ? 0 : ((visits / dailyTarget) * 100).clamp(0, 100).round();

    return {
      'period': 'custom',
      'percent': percent,
      'target': dailyTarget.round(),
      'visits': visits,
      'orders': orders,
      'wonSales': wonSales,
      'visitedSchools': visitedSchools,
      'schools': schools,
      'institutions': institutions,
      'bookshops': bookshops,
      'pipeline': 0,
      'daysWorked': 0,
    };
  }

  Future<void> createTask(TaskModel task) async {
    try {
      await _supabase.from('tasks').insert(task.toMap());
      debugPrint("Task ${task.title} saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving task to Supabase: $e");
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await deleteByIdWithOfflineQueue(table: 'tasks', id: taskId);
      debugPrint("Task $taskId deleted from Supabase.");
    } catch (e) {
      debugPrint("Error deleting task $taskId from Supabase: $e");
      rethrow;
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      await updateByIdWithOfflineQueue(
        table: 'tasks',
        id: taskId,
        payload: {'status': status},
      );
      debugPrint("Task $taskId status updated to $status.");
    } catch (e) {
      debugPrint("Error updating task $taskId status: $e");
      rethrow;
    }
  }

  Future<int> getCurrentUserRole() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return 3; // Default to field agent
    final user = await getUser(currentUser.id);
    return user?.role ?? 3;
  }

  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  Future<bool> schoolExists(String schoolId) async {
    try {
      final row =
          await _supabase
              .from('schools')
              .select('id')
              .eq('id', schoolId)
              .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint("Error checking school existence for $schoolId: $e");
      return false;
    }
  }

  Future<List<MessageModel>> getMessagesForCurrentUser() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return <MessageModel>[];

      final data = await _supabase
          .from('messages')
          .select()
          .or(
            'sender_id.eq.${currentUser.id},recipient_id.eq.${currentUser.id}',
          )
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) => MessageModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting messages from Supabase: $e");
      return <MessageModel>[];
    }
  }

  Future<void> sendMessage(MessageModel message) async {
    try {
      await _supabase.from('messages').insert(message.toMap());
      debugPrint("Message ${message.id} saved to Supabase.");
    } catch (e) {
      debugPrint("Error saving message to Supabase: $e");
      rethrow;
    }
  }

  Future<List<CatalogItemModel>> getCatalogItems({
    String? itemType,
    bool activeOnly = true,
  }) async {
    final box = await _catalogBox;
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (!connectivityResult.contains(ConnectivityResult.none)) {
        final response =
            itemType == null
                ? await _supabase
                    .from('catalog_items')
                    .select()
                    .order('category')
                    .order('name')
                : await _supabase
                    .from('catalog_items')
                    .select()
                    .eq('item_type', itemType)
                    .order('category')
                    .order('name');

        final items =
            (response as List)
                .map(
                  (item) => CatalogItemModel.fromMap(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();

        // Cache items locally to ensure offline availability
        for (var item in items) {
          await box.put(item.sku, item.toMap());
        }
      }
    } catch (e) {
      debugPrint("Error fetching catalog items from Supabase: $e");
    }

    // Read from local cache
    var cachedItems =
        box.values
            .map((e) => CatalogItemModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();

    if (itemType != null) {
      cachedItems =
          cachedItems.where((item) => item.itemType == itemType).toList();
    }
    if (activeOnly) {
      cachedItems = cachedItems.where((item) => item.isActive).toList();
    }

    cachedItems.sort((a, b) => a.name.compareTo(b.name));
    return cachedItems;
  }

  Future<List<CatalogItemModel>> getSampleCatalogItemsFromTable() async {
    try {
      final response = await _supabase
          .from('catalog_items')
          .select()
          .order('name', ascending: true);

      final items =
          List<Map<String, dynamic>>.from(response)
              .where((row) {
                final isActive = (row['is_active'] ?? true) == true;
                final itemType =
                    (row['item_type'] ?? '').toString().toLowerCase();
                return isActive && itemType.contains('sample');
              })
              .map(
                (row) =>
                    CatalogItemModel.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList();

      final box = await _catalogBox;
      for (final item in items) {
        await box.put(item.sku, item.toMap());
      }
      return items;
    } catch (e) {
      debugPrint('Error fetching sample catalog items: $e');
      final fallback = await getCatalogItems(itemType: null, activeOnly: true);
      return fallback
          .where(
            (item) => item.itemType.trim().toLowerCase().contains('sample'),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
  }

  Future<void> upsertCatalogItems(List<CatalogItemModel> items) async {
    try {
      if (items.isEmpty) return;
      final box = await _catalogBox;
      for (var item in items) {
        // Force isSynced false until the background sync guarantees successful push
        final localItem = CatalogItemModel(
          id: item.id,
          name: item.name,
          category: item.category,
          sku: item.sku,
          itemType: item.itemType,
          unitPrice: item.unitPrice,
          stockQty: item.stockQty,
          description: item.description,
          isActive: item.isActive,
          isSynced: false,
        );
        await box.put(item.sku, localItem.toMap());
      }
      if (await _canManageCatalogItems()) {
        await syncData(); // Push unsynced data immediately
      } else {
        debugPrint(
          'Catalog items saved locally only because the current user cannot write catalog data.',
        );
      }
    } catch (e) {
      debugPrint("Error saving catalog items locally: $e");
      rethrow;
    }
  }

  Future<void> decrementCatalogStock(String itemId, int quantity) async {
    try {
      final current =
          await _supabase
              .from('catalog_items')
              .select('stock_qty')
              .eq('id', itemId)
              .maybeSingle();
      final currentStock = (current?['stock_qty'] as num?)?.toInt() ?? 0;
      final newStock = (currentStock - quantity).clamp(0, 1 << 30);
      await _supabase
          .from('catalog_items')
          .update({'stock_qty': newStock})
          .eq('id', itemId);
    } catch (e) {
      debugPrint("Error updating catalog stock: $e");
      rethrow;
    }
  }

  Future<void> recordSampleDistribution({
    required String schoolId,
    required String sampleName,
    required String sampleCategory,
    String? agentId,
    int quantity = 1,
    String? notes,
    String? stampedReceiptUrl,
    String? stampedReceiptPath,
    String? clientType,
    int returnedQty = 0,
  }) async {
    try {
      final payload = <String, dynamic>{
        'school_id': schoolId,
        'agent_id': agentId ?? getCurrentUserId(),
        'sample_name': sampleName,
        'sample_category': sampleCategory,
        'client_type': clientType,
        'quantity': quantity,
        'returned_qty': returnedQty,
        'stamped_receipt_url': stampedReceiptUrl,
        'stamped_receipt_path': stampedReceiptPath,
        'notes': notes,
        'distributed_at': DateTime.now().toIso8601String(),
      };
      await _insertWithOfflineQueue(
        table: 'school_sample_distributions',
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error saving sample distribution record: $e");
      rethrow;
    }
  }

  Future<void> recordSchoolVisit({
    required String schoolId,
    required String agentId,
    String? outcome,
    String? notes,
    String? visitStatus,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? photoPath,
  }) async {
    try {
      final payload = <String, dynamic>{
        'school_id': schoolId,
        'agent_id': agentId,
        'outcome': outcome,
        'notes': notes,
        'visit_status': visitStatus ?? 'completed',
        'latitude': latitude,
        'longitude': longitude,
        'photo_url': photoUrl,
        'photo_path': photoPath,
        'visited_at': DateTime.now().toIso8601String(),
      };
      await _insertWithOfflineQueue(table: 'school_visits', payload: payload);
    } catch (e) {
      debugPrint('Error recording school visit: $e');
      rethrow;
    }
  }

  Future<void> updateSampleReturnedQty(
    String distributionId,
    int returnedQty,
  ) async {
    try {
      await _supabase
          .from('school_sample_distributions')
          .update({'returned_qty': returnedQty < 0 ? 0 : returnedQty})
          .eq('id', distributionId);
    } catch (e) {
      debugPrint("Error updating returned sample quantity: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSampleDistributions({
    String? agentId,
    String? clientType,
    String? schoolId,
  }) async {
    try {
      var query = _supabase
          .from('school_sample_distributions')
          .select(
            'id, school_id, sample_name, sample_category, client_type, quantity, returned_qty, notes, distributed_at, schools(name, county, dealer_type)',
          );
      if (agentId != null) {
        query = query.eq('agent_id', agentId);
      }
      if (clientType != null) {
        query = query.eq('client_type', clientType);
      }
      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }
      final res = await query
          .order('distributed_at', ascending: false)
          .limit(5000);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error loading sample distributions: $e");
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> createSampleRequest({
    String? schoolId,
    required List<Map<String, dynamic>> items,
    String? clientType,
    String? requestedBy,
    String? purpose,
    String? notes,
    DateTime? neededBy,
  }) async {
    final requestCode =
        'SR-${DateTime.now().millisecondsSinceEpoch}-${(DateTime.now().microsecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    final payload = <String, dynamic>{
      'request_code': requestCode,
      'school_id': schoolId,
      'client_type': clientType,
      'requested_by': requestedBy ?? getCurrentUserId(),
      'purpose': purpose,
      'notes': notes,
      'status': 'PENDING',
      'needed_by': neededBy?.toIso8601String(),
      'requested_at': DateTime.now().toIso8601String(),
      'items': items,
    };
    final res =
        await _supabase
            .from('sample_requests')
            .insert(payload)
            .select()
            .single();
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getSampleRequests({
    String? status,
    String? agentId,
    String? schoolId,
  }) async {
    try {
      var query = _supabase
          .from('sample_requests')
          .select(
            'id, request_code, school_id, client_type, purpose, notes, status, rejection_reason, needed_by, requested_at, reviewed_at, items, schools(name, county)',
          );
      if (status != null) {
        query = query.eq('status', status);
      }
      if (agentId != null) {
        query = query.eq('requested_by', agentId);
      }
      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }
      final res = await query
          .order('requested_at', ascending: false)
          .limit(5000);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error loading sample requests: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> updateSampleRequestStatus({
    required String requestId,
    required String status,
    String? reviewedBy,
    String? rejectionReason,
    List<Map<String, dynamic>>? approvedItems,
  }) async {
    final payload = <String, dynamic>{
      'status': status,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': reviewedBy ?? getCurrentUserId(),
    };
    if (status == 'REJECTED') {
      payload['rejection_reason'] = rejectionReason;
    }
    if (status == 'APPROVED' && approvedItems != null) {
      payload['items'] = approvedItems;
    }
    await _supabase.from('sample_requests').update(payload).eq('id', requestId);
  }

  Future<void> saveDebtCollection({
    required String schoolId,
    required double amount,
    required String paymentMethod,
    String? paymentReference,
    String? notes,
    DateTime? collectedAt,
  }) async {
    final payload = <String, dynamic>{
      'school_id': schoolId,
      'collected_by': getCurrentUserId(),
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'notes': notes,
      'collected_at': (collectedAt ?? DateTime.now()).toIso8601String(),
    };
    await _insertWithOfflineQueue(table: 'debt_collections', payload: payload);
  }

  Future<void> _insertWithOfflineQueue({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).insert(payload);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    final op = <String, dynamic>{
      'table': table,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    };
    await pendingBox.add(op);
  }

  Future<void> insertWithOfflineQueue({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    await _insertWithOfflineQueue(table: table, payload: payload);
  }

  Future<void> upsertWithOfflineQueue({
    required String table,
    required Map<String, dynamic> payload,
    String? onConflict,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).upsert(payload, onConflict: onConflict);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    final op = <String, dynamic>{
      'op': 'upsert',
      'table': table,
      'payload': payload,
      'on_conflict': onConflict,
      'created_at': DateTime.now().toIso8601String(),
    };
    await pendingBox.add(op);
  }

  Future<void> updateByIdWithOfflineQueue({
    required String table,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).update(payload).eq('id', id);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    await pendingBox.add({
      'op': 'update',
      'table': table,
      'id': id,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteByIdWithOfflineQueue({
    required String table,
    required String id,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      await _supabase.from(table).delete().eq('id', id);
      return;
    }
    final pendingBox = await _pendingOpsBox;
    await pendingBox.add({
      'op': 'delete',
      'table': table,
      'id': id,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _syncPendingOps() async {
    final pendingBox = await _pendingOpsBox;
    final keys = pendingBox.keys.toList();
    for (final key in keys) {
      final raw = pendingBox.get(key);
      if (raw is! Map) continue;
      final table = raw['table']?.toString();
      final opType = raw['op']?.toString() ?? 'insert';
      final rowId = raw['id']?.toString();
      final payloadRaw = raw['payload'];
      if (table == null) {
        await pendingBox.delete(key);
        continue;
      }
      try {
        if (opType == 'upsert') {
          if (payloadRaw is! Map) {
            await pendingBox.delete(key);
            continue;
          }
          final payload = Map<String, dynamic>.from(payloadRaw);
          await _supabase
              .from(table)
              .upsert(payload, onConflict: raw['on_conflict']?.toString());
        } else if (opType == 'update') {
          if (rowId == null || payloadRaw is! Map) {
            await pendingBox.delete(key);
            continue;
          }
          final payload = Map<String, dynamic>.from(payloadRaw);
          await _supabase.from(table).update(payload).eq('id', rowId);
        } else if (opType == 'delete') {
          if (rowId == null) {
            await pendingBox.delete(key);
            continue;
          }
          await _supabase.from(table).delete().eq('id', rowId);
        } else {
          if (payloadRaw is! Map) {
            await pendingBox.delete(key);
            continue;
          }
          final payload = Map<String, dynamic>.from(payloadRaw);
          await _supabase.from(table).insert(payload);
        }
        await pendingBox.delete(key);
      } catch (e) {
        debugPrint("Pending op sync failed for $table: $e");
      }
    }
  }

  Future<List<OrderModel>> getOrdersForCurrentUser() async {
    try {
      final data = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);
      return (data as List)
          .map((item) => OrderModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint("Error getting orders from Supabase: $e");
      return <OrderModel>[];
    }
  }

  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    try {
      final data = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);
      return (data as List)
          .map(
            (item) => OrderItemModel.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint("Error getting order items from Supabase: $e");
      return <OrderItemModel>[];
    }
  }

  Future<OrderModel> createOrder({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    OrderModel? savedOrder;
    try {
      final insertedOrder =
          await _supabase
              .from('orders')
              .insert(order.toMap())
              .select()
              .single();
      savedOrder = OrderModel.fromMap(
        Map<String, dynamic>.from(insertedOrder as Map),
      );

      if (items.isNotEmpty) {
        final currentSavedOrder = savedOrder;
        final payload =
            items.map((item) {
              final map = item.toMap();
              map['order_id'] = currentSavedOrder.id;
              return map;
            }).toList();
        await _supabase.from('order_items').insert(payload);
      }

      debugPrint("Order ${savedOrder.orderNumber} saved to Supabase.");
      return savedOrder;
    } catch (e) {
      if (savedOrder != null) {
        try {
          await _supabase.from('orders').delete().eq('id', savedOrder.id);
        } catch (rollbackError) {
          debugPrint(
            "Rollback failed for order ${savedOrder.id}: $rollbackError",
          );
        }
      }
      debugPrint("Error creating order in Supabase: $e");
      rethrow;
    }
  }

  Future<OrderModel> createOrderWithSchoolSale({
    required OrderModel order,
    required List<OrderItemModel> items,
    required SchoolSaleModel sale,
  }) async {
    try {
      final result = await _supabase.rpc(
        'create_school_sale_checkout',
        params: {
          'order_payload': order.toMap(),
          'items_payload': items.map((item) => item.toMap()).toList(),
          'sale_payload': sale.toMap(),
        },
      );

      final response = Map<String, dynamic>.from(result as Map);
      final orderMap = Map<String, dynamic>.from(response['order'] as Map);
      return OrderModel.fromMap(orderMap);
    } catch (e) {
      debugPrint("Error creating atomic checkout transaction: $e");
      rethrow;
    }
  }

  Future<void> markMessageRead(String id) async {
    try {
      await updateByIdWithOfflineQueue(
        table: 'messages',
        id: id,
        payload: {'is_read': true},
      );
    } catch (e) {
      debugPrint("Error marking message read: $e");
      rethrow;
    }
  }

  Future<void> deleteMessage(String id) async {
    try {
      await deleteByIdWithOfflineQueue(table: 'messages', id: id);
    } catch (e) {
      debugPrint("Error deleting message: $e");
      rethrow;
    }
  }

  Future<SchoolSaleModel?> getLatestSchoolSale(String schoolId) async {
    try {
      final data =
          await _supabase
              .from('school_sales')
              .select()
              .eq('school_id', schoolId)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
      if (data == null) return null;
      return SchoolSaleModel.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint("Error loading latest school sale: $e");
      return null;
    }
  }

  Future<void> saveSchoolSale(SchoolSaleModel sale) async {
    try {
      await _supabase.from('school_sales').upsert(sale.toMap());
    } catch (e) {
      debugPrint("Error saving school sale: $e");
      rethrow;
    }
  }

  Future<void> createSchoolFollowUp({
    required String schoolId,
    required String nextStep,
    required DateTime dueAt,
    String? notes,
  }) async {
    try {
      await _supabase.from('school_follow_ups').insert({
        'school_id': schoolId,
        'agent_id': getCurrentUserId(),
        'next_step': nextStep,
        'due_at': dueAt.toIso8601String(),
        'notes': notes,
        'follow_up_status': 'open',
      });
    } catch (e) {
      debugPrint("Error creating school follow-up: $e");
      rethrow;
    }
  }

  Future<void> _syncEngagementToPipeline(SchoolModel school) async {
    final engagement = (school.engagementType ?? '').trim();
    if (engagement.isEmpty) return;

    final mappedStage = _pipelineStageFromEngagement(engagement);
    final latestSale = await getLatestSchoolSale(school.id);

    if (latestSale == null) {
      final sale = SchoolSaleModel(
        schoolId: school.id,
        agentId: getCurrentUserId(),
        packageName: engagement,
        expectedValue: 0,
        notes: 'Auto-created from onboarding engagement type: $engagement',
        stage: mappedStage,
        stageUpdatedAt: DateTime.now(),
        probability: _probabilityFromStage(mappedStage),
        isSynced: true,
      );
      await saveSchoolSale(sale);
      return;
    }

    final updated = SchoolSaleModel(
      id: latestSale.id,
      schoolId: latestSale.schoolId,
      agentId: latestSale.agentId ?? getCurrentUserId(),
      packageName:
          latestSale.packageName.isNotEmpty
              ? latestSale.packageName
              : engagement,
      expectedValue: latestSale.expectedValue,
      notes: latestSale.notes,
      stage: mappedStage,
      stageUpdatedAt: DateTime.now(),
      expectedCloseDate: latestSale.expectedCloseDate,
      probability: _probabilityFromStage(mappedStage),
      closedAt: latestSale.closedAt,
      isSynced: true,
      createdAt: latestSale.createdAt,
      updatedAt: DateTime.now(),
    );
    await saveSchoolSale(updated);
  }

  PipelineStage _pipelineStageFromEngagement(String engagement) {
    switch (engagement.toLowerCase()) {
      case 'cold lead':
      case 'new prospect':
        return PipelineStage.lead;
      case 'warm lead':
        return PipelineStage.contacted;
      case 'follow-up':
        return PipelineStage.decisionPending;
      case 'existing relationship':
        return PipelineStage.negotiation;
      default:
        return PipelineStage.lead;
    }
  }

  int _probabilityFromStage(PipelineStage stage) {
    switch (stage) {
      case PipelineStage.lead:
        return 10;
      case PipelineStage.contacted:
        return 25;
      case PipelineStage.meetingScheduled:
        return 35;
      case PipelineStage.sampleIssued:
        return 45;
      case PipelineStage.quotationSent:
        return 60;
      case PipelineStage.decisionPending:
        return 70;
      case PipelineStage.negotiation:
        return 80;
      case PipelineStage.won:
        return 100;
      case PipelineStage.lost:
        return 0;
      case PipelineStage.dormant:
        return 5;
    }
  }

  // ==================== Event Module Methods ====================

  Future<List<Map<String, dynamic>>> getEvents({
    String? status,
    String? region,
  }) async {
    try {
      var query = _supabase.from('events').select();
      if (status != null) query = query.eq('status', status);
      if (region != null) query = query.eq('region', region);
      final data = await query.order('start_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting events: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> getEvent(String id) async {
    try {
      final data =
          await _supabase.from('events').select().eq('id', id).maybeSingle();
      return data != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('Error getting event: $e');
      return null;
    }
  }

  Future<String?> createEvent(Map<String, dynamic> payload) async {
    try {
      final data =
          await _supabase.from('events').insert(payload).select().single();
      return data['id']?.toString();
    } catch (e) {
      debugPrint('Error creating event: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(String id, Map<String, dynamic> payload) async {
    try {
      await _supabase.from('events').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('Error updating event: $e');
      rethrow;
    }
  }

  Future<void> updateEventStatus(String id, String status) async {
    try {
      await _supabase.from('events').update({'status': status}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating event status: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventAssignments(String eventId) async {
    try {
      final data = await _supabase
          .from('event_assignments')
          .select('*, users(full_name, email, phone)')
          .eq('event_id', eventId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event assignments: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> assignAgentToEvent(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_assignments').insert(payload);
    } catch (e) {
      debugPrint('Error assigning agent to event: $e');
      rethrow;
    }
  }

  Future<void> removeEventAssignment(String assignmentId) async {
    try {
      await _supabase.from('event_assignments').delete().eq('id', assignmentId);
    } catch (e) {
      debugPrint('Error removing event assignment: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventCheckins(String eventId) async {
    try {
      final data = await _supabase
          .from('event_checkins')
          .select('*, users(full_name, email)')
          .eq('event_id', eventId)
          .order('checkin_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event checkins: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> checkinToEvent(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_checkins').insert(payload);
    } catch (e) {
      debugPrint('Error checking in to event: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventTasks(String eventId) async {
    try {
      final data = await _supabase
          .from('event_tasks')
          .select()
          .eq('event_id', eventId)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event tasks: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> createEventTask(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_tasks').insert(payload);
    } catch (e) {
      debugPrint('Error creating event task: $e');
      rethrow;
    }
  }

  Future<void> toggleEventTask(String taskId, bool completed) async {
    try {
      await _supabase
          .from('event_tasks')
          .update({
            'completed': completed,
            'completed_at': completed ? DateTime.now().toIso8601String() : null,
            'completed_by': completed ? getCurrentUserId() : null,
          })
          .eq('id', taskId);
    } catch (e) {
      debugPrint('Error toggling event task: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventLeads(String eventId) async {
    try {
      final data = await _supabase
          .from('event_leads')
          .select('*, schools(name), users(full_name)')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event leads: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> createEventLead(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_leads').insert(payload);
    } catch (e) {
      debugPrint('Error creating event lead: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventOrders(String eventId) async {
    try {
      final data = await _supabase
          .from('event_orders')
          .select('*, orders(*, order_items(*)), users(full_name)')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event orders: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> linkOrderToEvent(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_orders').insert(payload);
    } catch (e) {
      debugPrint('Error linking order to event: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventSamples(String eventId) async {
    try {
      final data = await _supabase
          .from('event_samples')
          .select('*, catalog_items(name, sku), users(full_name)')
          .eq('event_id', eventId)
          .order('distributed_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event samples: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> createEventSample(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_samples').insert(payload);
    } catch (e) {
      debugPrint('Error creating event sample: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventPhotos(String eventId) async {
    try {
      final data = await _supabase
          .from('event_photos')
          .select('*, users(full_name)')
          .eq('event_id', eventId)
          .order('uploaded_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event photos: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> uploadEventPhoto(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_photos').insert(payload);
    } catch (e) {
      debugPrint('Error uploading event photo: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEventExpenses(String eventId) async {
    try {
      final data = await _supabase
          .from('event_expenses')
          .select('*, users(full_name)')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting event expenses: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> createEventExpense(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('event_expenses').insert(payload);
    } catch (e) {
      debugPrint('Error creating event expense: $e');
      rethrow;
    }
  }

  Future<void> updateEventExpenseStatus(String expenseId, String status) async {
    try {
      await _supabase
          .from('event_expenses')
          .update({
            'status': status,
            'approved_by': getCurrentUserId(),
            'approved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', expenseId);
    } catch (e) {
      debugPrint('Error updating event expense status: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getEventReport(String eventId) async {
    try {
      final data =
          await _supabase
              .from('event_reports')
              .select()
              .eq('event_id', eventId)
              .maybeSingle();
      return data != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('Error getting event report: $e');
      return null;
    }
  }

  Future<void> saveEventReport(Map<String, dynamic> payload) async {
    try {
      final eventId = payload['event_id'];
      final existing =
          await _supabase
              .from('event_reports')
              .select('id')
              .eq('event_id', eventId)
              .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('event_reports')
            .update(payload)
            .eq('event_id', eventId);
      } else {
        await _supabase.from('event_reports').insert(payload);
      }
    } catch (e) {
      debugPrint('Error saving event report: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getEventSummary(String eventId) async {
    try {
      final results = await Future.wait([
        _supabase.from('event_checkins').select('id').eq('event_id', eventId),
        _supabase.from('event_leads').select('id').eq('event_id', eventId),
        _supabase.from('event_orders').select('id').eq('event_id', eventId),
        _supabase
            .from('event_samples')
            .select('id, quantity')
            .eq('event_id', eventId),
        _supabase
            .from('event_expenses')
            .select('amount, status')
            .eq('event_id', eventId),
        _supabase.from('event_photos').select('id').eq('event_id', eventId),
        _supabase
            .from('event_tasks')
            .select('id, completed')
            .eq('event_id', eventId),
      ]);

      final checkins = (results[0] as List).length;
      final leads = (results[1] as List).length;
      final orders = (results[2] as List).length;
      final samples = (results[3] as List).fold<int>(
        0,
        (sum, s) => sum + ((s['quantity'] as num?)?.toInt() ?? 0),
      );
      final expenses = (results[4] as List).fold<double>(
        0,
        (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0),
      );
      final photos = (results[5] as List).length;
      final tasks = (results[6] as List).length;
      final completedTasks =
          (results[6] as List).where((t) => t['completed'] == true).length;

      return {
        'checkins': checkins,
        'leads': leads,
        'orders': orders,
        'samples': samples,
        'expenses': expenses,
        'photos': photos,
        'tasks': tasks,
        'completed_tasks': completedTasks,
      };
    } catch (e) {
      debugPrint('Error getting event summary: $e');
      return {
        'checkins': 0,
        'leads': 0,
        'orders': 0,
        'samples': 0,
        'expenses': 0,
        'photos': 0,
        'tasks': 0,
        'completed_tasks': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getEventsDashboard({
    String? region,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('events').select();
      if (region != null) query = query.eq('region', region);
      if (startDate != null)
        query = query.gte('start_at', startDate.toIso8601String());
      if (endDate != null)
        query = query.lte('start_at', endDate.toIso8601String());
      final events = List<Map<String, dynamic>>.from(await query);

      final activeEvents =
          events
              .where(
                (e) => e['status'] == 'active' || e['status'] == 'in_progress',
              )
              .length;
      final upcomingEvents =
          events.where((e) => e['status'] == 'scheduled').length;
      final completedEvents =
          events.where((e) => e['status'] == 'completed').length;

      double totalRevenue = 0;
      double totalBudget = 0;
      double totalExpenses = 0;
      int totalLeads = 0;
      int totalOrders = 0;

      for (final event in events) {
        final eventId = event['id']?.toString();
        if (eventId == null) continue;

        final budget = event['budget'];
        if (budget is num) totalBudget += budget.toDouble();

        final summary = await getEventSummary(eventId);
        totalLeads += (summary['leads'] as int?) ?? 0;
        totalOrders += (summary['orders'] as int?) ?? 0;
        totalExpenses += (summary['expenses'] as double?) ?? 0;
      }

      final roi =
          totalExpenses > 0
              ? ((totalRevenue - totalExpenses) / totalExpenses * 100)
              : 0;

      return {
        'total_events': events.length,
        'active_events': activeEvents,
        'upcoming_events': upcomingEvents,
        'completed_events': completedEvents,
        'total_revenue': totalRevenue,
        'total_budget': totalBudget,
        'total_expenses': totalExpenses,
        'total_leads': totalLeads,
        'total_orders': totalOrders,
        'roi': roi,
        'events': events,
      };
    } catch (e) {
      debugPrint('Error getting events dashboard: $e');
      return {
        'total_events': 0,
        'active_events': 0,
        'upcoming_events': 0,
        'completed_events': 0,
        'total_revenue': 0,
        'total_budget': 0,
        'total_expenses': 0,
        'total_leads': 0,
        'total_orders': 0,
        'roi': 0,
        'events': <Map<String, dynamic>>[],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getTopPerformingEvents({
    int limit = 5,
  }) async {
    try {
      final events = await getEvents();
      final eventsWithMetrics = <Map<String, dynamic>>[];

      for (final event in events) {
        final eventId = event['id']?.toString();
        if (eventId == null) continue;
        final summary = await getEventSummary(eventId);
        eventsWithMetrics.add({...event, 'metrics': summary});
      }

      eventsWithMetrics.sort((a, b) {
        final aOrders = (a['metrics']['orders'] as int?) ?? 0;
        final bOrders = (b['metrics']['orders'] as int?) ?? 0;
        return bOrders.compareTo(aOrders);
      });

      return eventsWithMetrics.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting top performing events: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getTopEventAgents(String eventId) async {
    try {
      final assignments = await getEventAssignments(eventId);
      final agentsWithMetrics = <Map<String, dynamic>>[];

      for (final assignment in assignments) {
        final agentId = assignment['agent_id']?.toString();
        if (agentId == null) continue;

        final leads = await _supabase
            .from('event_leads')
            .select('id')
            .eq('event_id', eventId)
            .eq('agent_id', agentId);
        final orders = await _supabase
            .from('event_orders')
            .select('id')
            .eq('event_id', eventId)
            .eq('agent_id', agentId);

        agentsWithMetrics.add({
          ...assignment,
          'leads_count': (leads as List).length,
          'orders_count': (orders as List).length,
        });
      }

      agentsWithMetrics.sort((a, b) {
        final aOrders = (a['orders_count'] as int?) ?? 0;
        final bOrders = (b['orders_count'] as int?) ?? 0;
        return bOrders.compareTo(aOrders);
      });

      return agentsWithMetrics;
    } catch (e) {
      debugPrint('Error getting top event agents: $e');
      return <Map<String, dynamic>>[];
    }
  }
}

class SchoolSaveResult {
  const SchoolSaveResult({
    required this.syncedToDatabase,
    required this.message,
  });

  final bool syncedToDatabase;
  final String message;
}
