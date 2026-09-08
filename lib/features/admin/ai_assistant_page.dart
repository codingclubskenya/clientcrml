import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/config/api_config.dart';
import '../database/database_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isWaiting = false;
  int _currentUserRole = 5;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _dbService.getCurrentUserRole();
    if (!mounted) return;
    setState(() {
      _currentUserRole = role;
    });
  }

  Future<String?> _buildContext() async {
    try {
      final Map<String, dynamic> combinedContext = {};
      final reportTypes = [
        'sales_summary',
        'pipeline_analysis',
        'agent_performance',
        'regional_summary',
        'event_summary',
        'sample_roi',
        'targets_analysis',
      ];

      for (var type in reportTypes) {
        final cacheKey = 'report_${type}_$_currentUserRole';
        final cached = await _dbService.getCachedReport(cacheKey);
        if (cached != null && cached['report'] != null) {
          combinedContext[type] = cached['report'];
        }
      }

      if (combinedContext.isNotEmpty) {
        return jsonEncode(combinedContext);
      }
    } catch (e) {
      debugPrint('Error building AI context: $e');
    }
    return null;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isWaiting) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isWaiting = true;
    });
    _controller.clear();

    try {
      final contextData = await _buildContext();

      final response = await http.post(
        Uri.parse(ApiConfig.aiChatUrl()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages':
              _messages
                  .map((m) => {'role': m['role'], 'content': m['content']})
                  .toList(),
          'context': contextData,
        }),
      );

      if (!mounted) return;
      setState(() => _isWaiting = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final assistantMessage =
            data['choices']?[0]?['message']?['content'] ??
            'Sorry, I could not generate a response.';
        setState(() {
          _messages.add({'role': 'assistant', 'content': assistantMessage});
        });
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMessage =
            error?['error']?.toString() ??
            'AI assistant is temporarily unavailable. Please try again later.';
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Error: $errorMessage',
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWaiting = false;
        _messages.add({
          'role': 'assistant',
          'content':
              'Error: Unable to reach the AI assistant. Please check your connection and try again.',
        });
      });
    }
  }

  Future<void> _generateReport(String reportType, String label) async {
    if (_isWaiting) return;

    setState(() {
      _messages.add({'role': 'user', 'content': 'Generate $label report'});
      _isWaiting = true;
    });

    try {
      final cacheKey = 'report_${reportType}_${_currentUserRole}';
      final cachedReport = await _dbService.getCachedReport(cacheKey);
      if (cachedReport != null) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content':
                cachedReport['report']?.toString() ?? 'No report content.',
          });
          _isWaiting = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ai/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'report_type': reportType,
          'prompt':
              'Generate a comprehensive report with insights and recommendations.',
          'filters': {},
        }),
      );

      if (!mounted) return;
      setState(() => _isWaiting = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final report = data['report'] as String? ?? 'No report generated.';
        await _dbService.cacheReport(cacheKey, data);
        setState(() {
          _messages.add({'role': 'assistant', 'content': report});
        });
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        final errorMessage =
            error?['error']?.toString() ??
            'Report generation is temporarily unavailable. Please try again later.';
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Report error: $errorMessage',
          });
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWaiting = false;
        _messages.add({
          'role': 'assistant',
          'content':
              'Error: Unable to generate report. Please check your connection and try again.',
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _currentUserRole <= 2;
    if (!isManager) {
      return const Scaffold(
        body: Center(
          child: Text('Access restricted to Admin and Sales Manager roles.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _messages.isEmpty
                    ? const Center(
                      child: Text(
                        'Hello! How can I help you today?',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        return Align(
                          alignment:
                              isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isUser
                                      ? AppColors.primaryDark
                                      : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['content'] ?? '',
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          if (_isWaiting)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isWaiting ? null : _sendMessage,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _ReportChip(
                  label: 'Sales',
                  onTap:
                      () => _generateReport('sales_summary', 'Sales Summary'),
                ),
                const SizedBox(width: 8),
                _ReportChip(
                  label: 'Pipeline',
                  onTap:
                      () => _generateReport(
                        'pipeline_analysis',
                        'Pipeline Analysis',
                      ),
                ),
                const SizedBox(width: 8),
                _ReportChip(
                  label: 'Agents',
                  onTap:
                      () => _generateReport(
                        'agent_performance',
                        'Agent Performance',
                      ),
                ),
                const SizedBox(width: 8),
                _ReportChip(
                  label: 'Regions',
                  onTap:
                      () => _generateReport(
                        'regional_summary',
                        'Regional Summary',
                      ),
                ),
                const SizedBox(width: 8),
                _ReportChip(
                  label: 'Events',
                  onTap:
                      () => _generateReport('event_summary', 'Event Summary'),
                ),
                const SizedBox(width: 8),
                _ReportChip(
                  label: 'Samples',
                  onTap: () => _generateReport('sample_roi', 'Sample ROI'),
                ),
                const SizedBox(width: 8),
                _ReportChip(
                  label: 'Targets',
                  onTap:
                      () => _generateReport(
                        'targets_analysis',
                        'Targets Analysis',
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ReportChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReportChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.primaryPale,
      labelStyle: const TextStyle(color: AppColors.primaryDark),
      onPressed: onTap,
    );
  }
}
