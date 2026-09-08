import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/agent_dashboard_page.dart';
import '../../models/user_model.dart';
import '../database/database_service.dart';

class Role4AgentsPage extends StatefulWidget {
  const Role4AgentsPage({super.key});

  @override
  State<Role4AgentsPage> createState() => _Role4AgentsPageState();
}

class _Role4AgentsPageState extends State<Role4AgentsPage> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  List<UserModel> _agents = [];
  List<UserModel> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final currentAgent = await _dbService.getUser(currentUser.id);
    if (currentAgent == null || currentAgent.role != 4) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AgentDashboardPage()),
        (route) => false,
      );
      return;
    }

    final agentRegion = (currentAgent.region ?? '').toLowerCase();
    final members =
        agentRegion.isEmpty
            ? <UserModel>[]
            : (await _dbService.getRegionAssignments(
              currentAgent.region!,
            )).where((u) => u.role == 5).toList();

    if (!mounted) return;
    setState(() {
      _agents = [currentAgent];
      _allUsers = [currentAgent, ...members];
      _isLoading = false;
    });
  }

  List<UserModel> _membersForAgent(UserModel agent) {
    final agentRegion = (agent.region ?? '').toLowerCase();
    if (agentRegion.isEmpty) return const <UserModel>[];
    return _allUsers
        .where(
          (u) => u.role == 5 && (u.region ?? '').toLowerCase() == agentRegion,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role 4 Agents'),
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
              : _agents.isEmpty
              ? const Center(child: Text('No Role 4 agents found.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _agents.length,
                itemBuilder: (context, index) {
                  final agent = _agents[index];
                  final members = _membersForAgent(agent);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    color: AppColors.surfaceWhite,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: AppColors.borderGrey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        agent.fullName ?? agent.email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Region: ${agent.region ?? "Unassigned"}'),
                      trailing: Chip(
                        label: Text('${members.length} members'),
                        backgroundColor: AppColors.primaryPale,
                        labelStyle: const TextStyle(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      children: [
                        const Divider(height: 1),
                        if (members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No members assigned to this agent.'),
                          )
                        else
                          ...members.map((member) {
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryPale,
                                child: Text(
                                  (member.fullName ?? member.email).isNotEmpty
                                      ? (member.fullName ?? member.email)[0]
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              title: Text(member.fullName ?? member.email),
                              subtitle: Text(member.email),
                            );
                          }),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
