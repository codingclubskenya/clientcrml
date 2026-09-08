import '../../models/region_model.dart';
import '../../models/user_model.dart';
import 'database_service.dart';

class RegionRepository {
  final DatabaseService _dbService;

  RegionRepository({DatabaseService? dbService})
    : _dbService = dbService ?? DatabaseService();

  Future<List<RegionModel>> getAllRegions() => _dbService.getAllRegions();

  Future<RegionModel?> getRegion(String id) => _dbService.getRegion(id);

  Future<void> createRegion(RegionModel region) =>
      _dbService.createRegion(region);

  Future<void> updateRegion(RegionModel region) =>
      _dbService.updateRegion(region);

  Future<void> deleteRegion(String id) => _dbService.deleteRegion(id);

  Future<void> assignAgent(String regionId, String agentId) =>
      _dbService.assignRegionToAgent(regionId, agentId);

  Future<void> assignSupervisor(String regionId, String supervisorId) =>
      _dbService.assignRegionSupervisor(regionId, supervisorId);

  Future<void> unassignSupervisor(String regionId) =>
      _dbService.unassignRegionSupervisor(regionId);

  Future<void> unassignAgent(String regionId) =>
      _dbService.unassignRegionFromAgent(regionId);

  Future<List<UserModel>> getMembers(String regionId) =>
      _dbService.getRegionAssignments(regionId);

  Future<void> addMember(String regionId, String memberId) =>
      _dbService.assignUserToRegion(regionId, memberId, 5);

  Future<void> removeMember(String regionId, String memberId) =>
      _dbService.unassignUserFromRegion(regionId, memberId);

  Future<void> promoteMemberToAgent(String regionId, String memberId) =>
      _dbService.promoteRegionMemberToAgent(regionId, memberId, role: 4);

  Future<void> addSupervisor(String regionId, String supervisorId) =>
      _dbService.addSupervisorToRegion(regionId, supervisorId);

  Future<void> addAgent(String regionId, String agentId) =>
      _dbService.addAgentToRegion(regionId, agentId);

  Future<UserModel?> getUser(String userId) => _dbService.getUser(userId);

  Future<void> saveUser(UserModel user) => _dbService.saveUser(user);
}
