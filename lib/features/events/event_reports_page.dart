import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventReportsPage extends StatefulWidget {
  const EventReportsPage({super.key});

  @override
  State<EventReportsPage> createState() => _EventReportsPageState();
}

class _EventReportsPageState extends State<EventReportsPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  Map<String, dynamic>? _report;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic>? _event;
  bool _loading = true;
  bool _generating = false;
  bool _canGenerate = false;

  final _summaryController = TextEditingController();
  final _challengesController = TextEditingController();
  final _recommendationsController = TextEditingController();

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map
      ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    try {
      final role = await _dbService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _canGenerate = role != 5;
        });
      }
    } catch (e) {
      debugPrint('Error checking role: $e');
    }
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final report = await _dbService.getEventReport(id);
      final summary = await _dbService.getEventSummary(id);
      final event = await _dbService.getEvent(id);

      if (report != null) {
        _summaryController.text = report['summary']?.toString() ?? '';
        _challengesController.text = report['challenges']?.toString() ?? '';
        _recommendationsController.text = report['recommendations']?.toString() ?? '';
      }

      setState(() {
        _report = report;
        _summary = summary;
        _event = event;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateReport() async {
    final id = _eventId;
    if (id == null) return;

    setState(() => _generating = true);
    try {
      final summary = await _dbService.getEventSummary(id);
      final currentUser = _supabase.auth.currentUser;

      final reportPayload = {
        'event_id': id,
        'created_by': currentUser?.id,
        'summary': _summaryController.text.trim().isEmpty
            ? _generateAutoSummary(summary)
            : _summaryController.text.trim(),
        'attendance_count': summary['checkins'] ?? 0,
        'visitors_count': summary['checkins'] ?? 0,
        'schools_count': 0,
        'qualified_leads_count': summary['leads'] ?? 0,
        'orders_count': summary['orders'] ?? 0,
        'revenue': 0,
        'expenses_summary': {'total': summary['expenses'] ?? 0},
        'challenges': _challengesController.text.trim(),
        'recommendations': _recommendationsController.text.trim(),
      };

      await _dbService.saveEventReport(reportPayload);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated successfully')),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    } finally {
      setState(() => _generating = false);
    }
  }

  String _generateAutoSummary(Map<String, dynamic> summary) {
    final checkins = summary['checkins'] ?? 0;
    final leads = summary['leads'] ?? 0;
    final orders = summary['orders'] ?? 0;
    final samples = summary['samples'] ?? 0;
    final expenses = summary['expenses'] ?? 0;

    return 'Event completed with $checkins check-ins, $leads leads captured, '
        'orders placed, $samples samples distributed, and KES $expenses in expenses.';
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _challengesController.dispose();
    _recommendationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_event != null) _buildEventHeader(),
                const SizedBox(height: 16),
                _buildMetricsGrid(),
                const SizedBox(height: 20),
                _buildSectionHeader('Post-Event Report'),
                const SizedBox(height: 12),
                TextField(
                  controller: _summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Event Summary',
                    border: OutlineInputBorder(),
                    hintText: 'Describe the overall event outcome',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _challengesController,
                  decoration: const InputDecoration(
                    labelText: 'Challenges Faced',
                    border: OutlineInputBorder(),
                    hintText: 'What challenges were encountered?',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _recommendationsController,
                  decoration: const InputDecoration(
                    labelText: 'Recommendations',
                    border: OutlineInputBorder(),
                    hintText: 'What recommendations for future events?',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                if (_canGenerate)
                  ElevatedButton.icon(
                    onPressed: _generating ? null : _generateReport,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_generating ? 'Generating...' : 'Generate / Update Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                if (_report != null) ...[
                  const SizedBox(height: 20),
                  _buildSectionHeader('Report History'),
                  const SizedBox(height: 12),
                  _buildReportHistory(),
                ],
              ],
            ),
    );
  }

  Widget _buildEventHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _event!['name']?.toString() ?? 'Event',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${_event!['venue'] ?? ''} • ${_event!['region'] ?? ''}'),
          if (_event!['start_at'] != null)
            Text('Date: ${EventDateFormat.formatShort(_event!['start_at'])}', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = [
      _ReportMetric('Check-ins', '${_summary['checkins'] ?? 0}', Icons.login, Colors.blue),
      _ReportMetric('Leads', '${_summary['leads'] ?? 0}', Icons.people, Colors.purple),
      _ReportMetric('Orders', '${_summary['orders'] ?? 0}', Icons.shopping_cart, Colors.green),
      _ReportMetric('Samples', '${_summary['samples'] ?? 0}', Icons.inventory, Colors.orange),
      _ReportMetric('Photos', '${_summary['photos'] ?? 0}', Icons.photo, Colors.pink),
      _ReportMetric('Tasks Done', '${_summary['completed_tasks'] ?? 0}/${_summary['tasks'] ?? 0}', Icons.check_circle, Colors.teal),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: m.color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: m.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(m.icon, color: m.color, size: 20),
              const SizedBox(height: 4),
              Text(
                m.value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: m.color,
                ),
              ),
              Text(
                m.label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_report!['summary'] != null) ...[
            const Text('Summary:', style: TextStyle(fontWeight: FontWeight.w500)),
            Text(_report!['summary'].toString()),
            const SizedBox(height: 12),
          ],
          if (_report!['challenges'] != null) ...[
            const Text('Challenges:', style: TextStyle(fontWeight: FontWeight.w500)),
            Text(_report!['challenges'].toString()),
            const SizedBox(height: 12),
          ],
          if (_report!['recommendations'] != null) ...[
            const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.w500)),
            Text(_report!['recommendations'].toString()),
          ],
          const SizedBox(height: 12),
          Text(
            'Last updated: ${EventDateFormat.format(_report!['updated_at'] ?? _report!['created_at'])}',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ReportMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _ReportMetric(this.label, this.value, this.icon, this.color);
}
