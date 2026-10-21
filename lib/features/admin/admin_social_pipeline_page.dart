import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_service.dart';
import '../profile/crm_notification_service.dart';
import 'admin_social_inbox_page.dart';
import '../../services/api_service.dart';

class AdminSocialPipelinePage extends StatefulWidget {
  const AdminSocialPipelinePage({super.key});

  @override
  State<AdminSocialPipelinePage> createState() =>
      _AdminSocialPipelinePageState();
}

class _AdminSocialPipelinePageState extends State<AdminSocialPipelinePage> {
  final _dbService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

  static const String _directFacebookUrl =
      'https://www.facebook.com/longhornpublishers/';
  static const String _directWhatsAppPhone = '0798734442';
  static const List<String> _pipelineStages = <String>[
    'all',
    'lead',
    'contacted',
    'meeting_scheduled',
    'negotiation',
    'won',
    'lost',
  ];

  bool _isLoading = true;
  List<_SocialLead> _allLeads = <_SocialLead>[];
  String _selectedStageFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPipeline();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPipeline() async {
    setState(() => _isLoading = true);
    try {
      final schoolsRes = await ApiService().getAll(
        'schools', orderBy: 'created_at', orderDir: 'DESC', limit: 500,
      );

      final salesRes = await ApiService().getAll(
        'school_sales', orderBy: 'stage_updated_at', orderDir: 'DESC', limit: 500,
      );

      final latestSaleBySchool = <String, Map<String, dynamic>>{};
      for (final sale in List<Map<String, dynamic>>.from(salesRes)) {
        final schoolId = (sale['school_id'] ?? '').toString();
        if (schoolId.isNotEmpty && !latestSaleBySchool.containsKey(schoolId)) {
          latestSaleBySchool[schoolId] = sale;
        }
      }

      final leads = <_SocialLead>[];
      for (final school in List<Map<String, dynamic>>.from(schoolsRes)) {
        final source = (school['source'] ?? '').toString().toLowerCase().trim();
        if (source != 'facebook' && source != 'whatsapp') {
          continue;
        }

        final schoolId = (school['id'] ?? '').toString();
        final sale = latestSaleBySchool[schoolId];

        leads.add(
          _SocialLead(
            schoolName: (school['name'] ?? 'Unknown school').toString(),
            schoolId: schoolId,
            saleId: (sale?['id'] ?? '').toString(),
            phone: (school['phone'] ?? '').toString(),
            source: source,
            stage: (sale?['sale_status'] ?? 'lead').toString(),
            expectedValue: ((sale?['expected_value'] ?? 0) as num).toDouble(),
            capturedBy: (school['captured_by'] ?? '').toString(),
            createdAt: DateTime.tryParse(
              (school['created_at'] ?? '').toString(),
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _allLeads = leads.isEmpty ? _dummyLeads() : leads;
      });
    } catch (e) {
      if (!mounted) return;
      await CrmNotificationService.showIfEnabled(
        context,
        message: 'Failed to load social pipeline: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facebookLeads =
        _allLeads.where((l) => l.source == 'facebook').toList();
    final whatsappLeads =
        _allLeads.where((l) => l.source == 'whatsapp').toList();
    final totalExpectedValue = _allLeads.fold<double>(
      0,
      (sum, l) => sum + l.expectedValue,
    );
    final wonCount =
        _allLeads.where((l) => l.stage.toLowerCase() == 'won').length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Facebook & WhatsApp Pipeline'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Facebook'), Tab(text: 'WhatsApp')],
          ),
          actions: [
            IconButton(
              tooltip: 'Open Social Inbox',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSocialInboxPage(),
                  ),
                );
              },
              icon: const Icon(Icons.forum_outlined),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadPipeline,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _countCard(
                              'Facebook Leads',
                              facebookLeads.length,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _countCard(
                              'WhatsApp Leads',
                              whatsappLeads.length,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _countCard(
                              'Won Deals',
                              wonCount,
                              trailing:
                                  'KES ${totalExpectedValue.toStringAsFixed(0)}',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search school, phone, or owner',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    _searchController.text.isEmpty
                                        ? null
                                        : IconButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedStageFilter,
                              decoration: InputDecoration(
                                labelText: 'Stage',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items:
                                  _pipelineStages
                                      .map(
                                        (stage) => DropdownMenuItem(
                                          value: stage,
                                          child: Text(_stageLabel(stage)),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _selectedStageFilter = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _openDirectWhatsApp,
                            icon: const Icon(Icons.chat),
                            label: const Text('Open Direct WhatsApp'),
                          ),
                          FilledButton.icon(
                            onPressed: _openDirectFacebook,
                            icon: const Icon(Icons.facebook),
                            label: const Text('Open Direct Facebook'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildList(_applyFilters(facebookLeads)),
                          _buildList(_applyFilters(whatsappLeads)),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _countCard(String label, int count, {String? trailing}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (trailing != null) ...[
              const SizedBox(height: 4),
              Text(
                trailing,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_SocialLead> leads) {
    if (leads.isEmpty) {
      return const Center(child: Text('No leads found for this channel yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final lead = leads[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    lead.source == 'facebook' ? Icons.facebook : Icons.chat,
                    color:
                        lead.source == 'facebook'
                            ? Colors.indigo
                            : Colors.green,
                  ),
                  title: Text(lead.schoolName),
                  subtitle: Text(
                    'Stage: ${lead.stage}\n'
                    'Expected: KES ${lead.expectedValue.toStringAsFixed(0)}\n'
                    'Phone: ${lead.phone.isEmpty ? 'N/A' : lead.phone}',
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lead.capturedBy.isEmpty
                            ? 'Unassigned'
                            : lead.capturedBy,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(lead.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _stageBadge(lead.stage),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(lead),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openFacebook(lead),
                      icon: const Icon(Icons.facebook, size: 18),
                      label: const Text('Facebook'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showStagePicker(lead),
                        icon: const Icon(Icons.sync_alt, size: 18),
                        label: const Text('Update Stage'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openWhatsApp(_SocialLead lead) async {
    final cleanPhone = _normalizePhone(lead.phone);
    if (cleanPhone.isEmpty) {
      _showInfo('No phone number found for this lead.');
      return;
    }

    final message = Uri.encodeComponent('Hello ${lead.schoolName}');
    final deepLink = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=$message',
    );
    final webLink = Uri.parse('https://wa.me/$cleanPhone?text=$message');

    final openedApp = await launchUrl(
      deepLink,
      mode: LaunchMode.externalApplication,
    );
    if (!openedApp) {
      final openedWeb = await launchUrl(
        webLink,
        mode: LaunchMode.externalApplication,
      );
      if (!openedWeb) _showInfo('Could not open WhatsApp.');
    }
  }

  Future<void> _openFacebook(_SocialLead lead) async {
    final query = Uri.encodeComponent(lead.schoolName);
    final facebookSearch = Uri.parse(
      'https://www.facebook.com/search/top?q=$query',
    );
    final opened = await launchUrl(
      facebookSearch,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _showInfo('Could not open Facebook.');
  }

  Future<void> _openDirectWhatsApp() async {
    final message = Uri.encodeComponent('Hello Longhorn Publishers');
    final directPhone = _normalizePhone(_directWhatsAppPhone);
    final deepLink = Uri.parse(
      'whatsapp://send?phone=$directPhone&text=$message',
    );
    final webLink = Uri.parse('https://wa.me/$directPhone?text=$message');

    final openedApp = await launchUrl(
      deepLink,
      mode: LaunchMode.externalApplication,
    );
    if (!openedApp) {
      final openedWeb = await launchUrl(
        webLink,
        mode: LaunchMode.externalApplication,
      );
      if (!openedWeb) _showInfo('Could not open direct WhatsApp.');
    }
  }

  Future<void> _openDirectFacebook() async {
    final opened = await launchUrl(
      Uri.parse(_directFacebookUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _showInfo('Could not open direct Facebook page.');
  }

  void _showInfo(String message) {
    CrmNotificationService.showIfEnabled(context, message: message);
  }

  List<_SocialLead> _applyFilters(List<_SocialLead> leads) {
    final query = _searchController.text.trim().toLowerCase();
    return leads.where((lead) {
      final matchesStage =
          _selectedStageFilter == 'all' ||
          lead.stage.toLowerCase() == _selectedStageFilter;
      if (!matchesStage) return false;
      if (query.isEmpty) return true;
      return lead.schoolName.toLowerCase().contains(query) ||
          lead.phone.toLowerCase().contains(query) ||
          lead.capturedBy.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showStagePicker(_SocialLead lead) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children:
                  _pipelineStages
                      .where((s) => s != 'all')
                      .map(
                        (stage) => ListTile(
                          title: Text(_stageLabel(stage)),
                          trailing:
                              lead.stage.toLowerCase() == stage
                                  ? const Icon(Icons.check)
                                  : null,
                          onTap: () => Navigator.pop(context, stage),
                        ),
                      )
                      .toList(),
            ),
          ),
    );

    if (picked == null || picked == lead.stage.toLowerCase()) return;
    await _updateLeadStage(lead, picked);
  }

  Future<void> _updateLeadStage(_SocialLead lead, String nextStage) async {
    try {
      await _dbService.upsertWithOfflineQueue(
        table: 'school_sales',
        payload: {
          'id': lead.saleId.isEmpty ? null : lead.saleId,
          'school_id': lead.schoolId,
          'sale_status': nextStage,
          'expected_value': lead.expectedValue,
          'stage_updated_at': DateTime.now().toIso8601String(),
        },
      );

      _showInfo('Stage updated to ${_stageLabel(nextStage)}');
      await _loadPipeline();
    } catch (e) {
      _showInfo('Failed to update stage: $e');
    }
  }

  String _normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';
    if (digitsOnly.startsWith('0') && digitsOnly.length == 10) {
      return '254${digitsOnly.substring(1)}';
    }
    if (digitsOnly.startsWith('254')) return digitsOnly;
    return digitsOnly;
  }

  String _stageLabel(String stage) {
    return stage
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  Widget _stageBadge(String stage) {
    final lower = stage.toLowerCase();
    Color bg;
    Color fg;

    switch (lower) {
      case 'won':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'lost':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      case 'negotiation':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        break;
      case 'meeting_scheduled':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _stageLabel(lower),
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

List<_SocialLead> _dummyLeads() {
  return const [
    _SocialLead(
      schoolName: 'Green Valley School',
      schoolId: 'dummy-1',
      saleId: 'dummy-sale-1',
      phone: '0798734442',
      source: 'facebook',
      stage: 'contacted',
      expectedValue: 120000,
      capturedBy: 'sales@dehus.com',
      createdAt: null,
    ),
    _SocialLead(
      schoolName: 'Sunrise Academy',
      schoolId: 'dummy-2',
      saleId: 'dummy-sale-2',
      phone: '0712345678',
      source: 'facebook',
      stage: 'meeting_scheduled',
      expectedValue: 85000,
      capturedBy: 'agent@dehus.com',
      createdAt: null,
    ),
    _SocialLead(
      schoolName: 'Hilltop Primary',
      schoolId: 'dummy-3',
      saleId: 'dummy-sale-3',
      phone: '0700111222',
      source: 'whatsapp',
      stage: 'lead',
      expectedValue: 60000,
      capturedBy: 'manager@dehus.com',
      createdAt: null,
    ),
    _SocialLead(
      schoolName: 'Lakeview School',
      schoolId: 'dummy-4',
      saleId: 'dummy-sale-4',
      phone: '0722333444',
      source: 'whatsapp',
      stage: 'negotiation',
      expectedValue: 145000,
      capturedBy: 'sales@dehus.com',
      createdAt: null,
    ),
  ];
}

class _SocialLead {
  const _SocialLead({
    required this.schoolName,
    required this.schoolId,
    required this.saleId,
    required this.phone,
    required this.source,
    required this.stage,
    required this.expectedValue,
    required this.capturedBy,
    required this.createdAt,
  });

  final String schoolName;
  final String schoolId;
  final String saleId;
  final String phone;
  final String source;
  final String stage;
  final double expectedValue;
  final String capturedBy;
  final DateTime? createdAt;
}
