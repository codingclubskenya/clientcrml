import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, this.entityId});

  final String? entityId; // Optional: filter for a specific entity

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch from audit_events
      final auditRes = await ApiService().getAll(
        'audit_events',
        filter: widget.entityId == null ? null : {'entity_id': widget.entityId},
        orderBy: 'created_at', orderDir: 'DESC', limit: 100,
      );

      // 2. Fetch from pipeline_history
      final pipeRes = await ApiService().getAll(
        'pipeline_history',
        filter: widget.entityId == null ? null : {'pipeline_id': widget.entityId},
        orderBy: 'changed_at', orderDir: 'DESC', limit: 100,
      );

      final List<Map<String, dynamic>> combined = [];

      for (final a in auditRes) {
        Map<String, dynamic>? actor;
        final actorId = a['actor_id']?.toString();
        if (actorId != null) {
          try {
            actor = Map<String, dynamic>.from(
              await ApiService().getById('users', actorId),
            );
          } catch (_) {}
        }
        combined.add({
          'date': DateTime.parse(a['created_at'].toString()),
          'title': '${a['action']} ${a['entity_type']}',
          'subtitle': 'By ${actor?['full_name'] ?? 'System'}',
          'details': 'ID: ${a['entity_id']}',
          'icon': Icons.history,
          'color': Colors.blue,
        });
      }

      for (final p in pipeRes) {
        Map<String, dynamic>? actor;
        final actorId = p['changed_by']?.toString();
        if (actorId != null) {
          try {
            actor = Map<String, dynamic>.from(
              await ApiService().getById('users', actorId),
            );
          } catch (_) {}
        }
        combined.add({
          'date': DateTime.parse(p['changed_at'].toString()),
          'title': 'Pipeline Stage Change',
          'subtitle': '${p['old_stage'] ?? 'Lead'} → ${p['new_stage']}',
          'details': 'By ${actor?['full_name'] ?? 'System'}',
          'icon': Icons.swap_horiz,
          'color': Colors.purple,
        });
      }

      combined.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );
      _logs = combined;
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entityId != null ? 'Audit History' : 'Global Audit Log',
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
              ? const Center(child: Text('No audit events found.'))
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final date = log['date'] as DateTime;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        log['icon'] as IconData,
                        color: log['color'] as Color,
                      ),
                      title: Text(
                        log['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log['subtitle'] as String),
                          Text(
                            log['details'] as String,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
