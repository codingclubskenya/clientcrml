import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/colors.dart';
import 'audit_log_page.dart';
import '../../core/widgets/map_tile_controls.dart';

class SchoolProfilePage extends StatefulWidget {
  const SchoolProfilePage({super.key, required this.schoolId});

  final String schoolId;

  @override
  State<SchoolProfilePage> createState() => _SchoolProfilePageState();
}

class _SchoolProfilePageState extends State<SchoolProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  Map<String, dynamic>? _schoolData;
  Map<String, dynamic>? _activeSale;
  List<Map<String, dynamic>> _visits = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _timeline = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _supabase.from('schools').select().eq('id', widget.schoolId).single(),
        _supabase
            .from('school_sales')
            .select()
            .eq('school_id', widget.schoolId)
            .maybeSingle(),
        _supabase
            .from('school_visits')
            .select()
            .eq('school_id', widget.schoolId)
            .order('visited_at', ascending: false),
        _supabase
            .from('opportunity_activities')
            .select()
            .eq('school_id', widget.schoolId)
            .order('created_at', ascending: false),
        _supabase
            .from('orders')
            .select()
            .eq('school_id', widget.schoolId)
            .order('created_at', ascending: false),
      ]);

      _schoolData = responses[0] as Map<String, dynamic>;
      _activeSale = responses[1] as Map<String, dynamic>?;
      _visits = List<Map<String, dynamic>>.from(responses[2] as List);
      _activities = List<Map<String, dynamic>>.from(responses[3] as List);
      _orders = List<Map<String, dynamic>>.from(responses[4] as List);

      _buildTimeline();
    } catch (e) {
      debugPrint('Error fetching school profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildTimeline() {
    final List<Map<String, dynamic>> items = [];

    for (var v in _visits) {
      items.add({
        'type': 'visit',
        'date': DateTime.parse(v['visited_at'].toString()),
        'title': 'Field Visit',
        'subtitle': v['outcome'] ?? 'No outcome logged',
        'notes': v['notes'],
        'icon': Icons.directions_walk,
        'color': AppColors.primaryGreen,
      });
    }

    for (var a in _activities) {
      items.add({
        'type': 'activity',
        'date': DateTime.parse(a['created_at'].toString()),
        'title': a['activity_type'] ?? 'Sales Activity',
        'subtitle': a['activity_outcome'] ?? '',
        'notes': a['notes'],
        'icon': Icons.call,
        'color': Colors.blue,
      });
    }

    for (var o in _orders) {
      items.add({
        'type': 'order',
        'date': DateTime.parse(o['created_at'].toString()),
        'title': 'Order ${o['order_number']}',
        'subtitle': 'Amount: KES ${o['checkout_amount']}',
        'notes': 'Status: ${o['status']}',
        'icon': Icons.shopping_bag,
        'color': Colors.orange,
      });
    }

    items.sort(
      (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
    );
    _timeline = items;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_schoolData == null) {
      return const Scaffold(body: Center(child: Text('School not found.')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.longhornMaroon,
          foregroundColor: Colors.white,
          title: Text(
            _schoolData!['name'] ?? 'School Profile',
            style: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Sales Pipeline'),
              Tab(text: 'Timeline'),
              Tab(text: 'Financials'),
            ],
          ),
          actions: [
            _buildLeadScoreBadge(),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Profile',
              onPressed: _openEditDialog,
            ),
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.white),
              tooltip: 'Call & Log',
              onPressed: () => _launchPhone(),
            ),
            IconButton(
              icon: const Icon(Icons.chat_outlined, color: Colors.white),
              tooltip: 'WhatsApp & Log',
              onPressed: () => _launchWhatsAppWithLog(),
            ),
            IconButton(
              icon: const Icon(Icons.email_outlined, color: Colors.white),
              tooltip: 'Email & Log',
              onPressed: () => _launchEmail(),
            ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: 'Audit History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AuditLogPage(entityId: widget.schoolId),
                  ),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildSalesTab(),
            _buildTimelineTab(),
            _buildFinancialsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final focusAreas = List<String>.from(_schoolData!['focusAreas'] ?? []);
    final lat = (_schoolData!['latitude'] as num?)?.toDouble();
    final lng = (_schoolData!['longitude'] as num?)?.toDouble();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final infoContent = [
      _buildInfoCard('General Information', [
        _infoRow('County', _schoolData!['county']),
        _infoRow('Phone', _schoolData!['phone']),
        _infoRow('Ownership', _schoolData!['school_ownership']),
        _infoRow('Population', _schoolData!['school_population']?.toString()),
        _infoRow('Category', _schoolData!['book_category']),
      ]),
      const SizedBox(height: 16),
      _buildInfoCard('Focus Areas', [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: focusAreas.map((f) => Chip(label: Text(f))).toList(),
        ),
      ]),
      const SizedBox(height: 16),
      _buildInfoCard('Internal Notes', [
        Text(_schoolData!['notes'] ?? 'No notes available.'),
      ]),
    ];

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Column(children: infoContent)),
            const SizedBox(width: 24),
            if (lat != null && lng != null)
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMapCard(lat, lng, height: 400),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...infoContent,
          const SizedBox(height: 16),
          if (lat != null && lng != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            _buildMapCard(lat, lng),
          ],
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    if (_activeSale == null) {
      return const Center(
        child: Text('No active sales opportunity found for this school.'),
      );
    }
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final saleContent = [
      _buildInfoCard('Opportunity Details', [
        _infoRow(
          'Current Stage',
          _activeSale!['sale_status']?.toString().toUpperCase(),
        ),
        _infoRow('Expected Value', 'KES ${_activeSale!['expected_value']}'),
        _infoRow('Probability', '${_activeSale!['probability']}%'),
        _infoRow(
          'Weighted Forecast',
          'KES ${_activeSale!['weighted_forecast']}',
        ),
      ]),
      const SizedBox(height: 16),
      _buildInfoCard('Next Steps', [
        _infoRow('Action', _activeSale!['next_action']),
        _infoRow('Due Date', _activeSale!['next_action_date']?.toString()),
      ]),
    ];

    final riskContent = _buildInfoCard('Risk & Status', [
      _infoRow('Risk Level', ''),
      Center(
        child: Text(
          _activeSale!['risk_level']?.toString().toUpperCase() ?? 'LOW',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color:
                _activeSale!['risk_level'] == 'high'
                    ? Colors.red
                    : Colors.green,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _infoRow(
        'SLA Due',
        _activeSale!['stage_sla_due_at']?.toString().split('T').first,
      ),
    ]);

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Column(children: saleContent)),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: riskContent),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [...saleContent, const SizedBox(height: 16), riskContent],
      ),
    );
  }

  Widget _buildTimelineTab() {
    if (_timeline.isEmpty) {
      return const Center(child: Text('No activities recorded yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _timeline.length,
      itemBuilder: (context, index) {
        final item = _timeline[index];
        final date = item['date'] as DateTime;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (item['color'] as Color).withValues(alpha: 0.1),
              child: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
              ),
            ),
            title: Text(
              item['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['subtitle'] as String),
                if (item['notes'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['notes'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialsTab() {
    if (_orders.isEmpty) {
      return const Center(child: Text('No orders found for this school.'));
    }

    final totalSpent = _orders.fold(
      0.0,
      (sum, o) => sum + (o['checkout_amount'] as num).toDouble(),
    );
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: AppColors.primaryGreen.withValues(alpha: 0.05),
          width: double.infinity,
          child: Column(
            children: [
              const Text(
                'Lifetime Value',
                style: TextStyle(color: Colors.grey),
              ),
              Text(
                'KES ${totalSpent.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              Text(
                '${_orders.length} total orders',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              isDesktop
                  ? GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _orders.length,
                    itemBuilder:
                        (context, index) => _buildOrderCard(_orders[index]),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder:
                        (context, index) => _buildOrderCard(_orders[index]),
                  ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.shopping_cart_outlined, size: 20),
        ),
        title: Text(
          'Order ${order['order_number']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Status: ${order['status']}',
          style: TextStyle(
            color:
                order['status'] == 'completed' ? Colors.green : Colors.orange,
          ),
        ),
        trailing: Text(
          'KES ${order['checkout_amount']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.longhornMaroon,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(double lat, double lng, {double height = 250}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(lat, lng),
          initialZoom: 14,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          MapTileLayer(
            userAgentPackageName: 'com.dehus.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadScoreBadge() {
    final score = _schoolData!['lead_score'] ?? 0;
    final color =
        score >= 70
            ? Colors.greenAccent
            : score >= 40
            ? Colors.orangeAccent
            : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          'Score: $score',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Future<void> _openEditDialog() async {
    final nameController = TextEditingController(
      text: _schoolData!['name']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: _schoolData!['phone']?.toString() ?? '',
    );
    final countyController = TextEditingController(
      text: _schoolData!['county']?.toString() ?? '',
    );
    final ownershipController = TextEditingController(
      text: _schoolData!['school_ownership']?.toString() ?? '',
    );
    final populationController = TextEditingController(
      text: _schoolData!['school_population']?.toString() ?? '',
    );
    final contactNameController = TextEditingController(
      text: _schoolData!['contact_name']?.toString() ?? '',
    );
    final contactPhoneController = TextEditingController(
      text: _schoolData!['contact_phone']?.toString() ?? '',
    );
    final focusAreasController = TextEditingController(
      text: List<String>.from(
        _schoolData!['focusAreas'] ?? const [],
      ).join(', '),
    );
    final notesController = TextEditingController(
      text: _schoolData!['notes']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit School Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _editProfileField(nameController, 'School Name'),
                  _editProfileField(
                    phoneController,
                    'Phone',
                    keyboardType: TextInputType.phone,
                  ),
                  _editProfileField(countyController, 'County'),
                  _editProfileField(ownershipController, 'Ownership'),
                  _editProfileField(
                    populationController,
                    'Population',
                    keyboardType: TextInputType.number,
                  ),
                  _editProfileField(contactNameController, 'Contact Name'),
                  _editProfileField(
                    contactPhoneController,
                    'Contact Phone',
                    keyboardType: TextInputType.phone,
                  ),
                  _editProfileField(focusAreasController, 'Focus Areas'),
                  _editProfileField(notesController, 'Notes', maxLines: 3),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty ||
                      phoneController.text.trim().isEmpty ||
                      countyController.text.trim().isEmpty) {
                    return;
                  }

                  final focusAreas =
                      focusAreasController.text
                          .split(',')
                          .map((value) => value.trim())
                          .where((value) => value.isNotEmpty)
                          .toList();

                  try {
                    await _supabase
                        .from('schools')
                        .update({
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'county': countyController.text.trim(),
                          'school_ownership':
                              ownershipController.text.trim().isEmpty
                                  ? null
                                  : ownershipController.text.trim(),
                          'school_population': int.tryParse(
                            populationController.text.trim(),
                          ),
                          'contact_name':
                              contactNameController.text.trim().isEmpty
                                  ? null
                                  : contactNameController.text.trim(),
                          'contact_phone':
                              contactPhoneController.text.trim().isEmpty
                                  ? null
                                  : contactPhoneController.text.trim(),
                          'focusAreas':
                              focusAreas.isEmpty
                                  ? const ['General']
                                  : focusAreas,
                          'notes':
                              notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                          'updated_at': DateTime.now().toIso8601String(),
                        })
                        .eq('id', widget.schoolId);

                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('School profile updated.')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update school profile: $e'),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (saved == true && mounted) {
      await _fetchData();
    }
  }

  Widget _editProfileField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _launchPhone() async {
    final phone = _schoolData!['phone']?.toString();
    if (phone != null) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          _showLogActivityDialog('Call');
        }
      }
    }
  }

  void _launchWhatsAppWithLog() async {
    final phone = _schoolData!['phone']?.toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (phone != null) {
      final uri = Uri.parse('https://wa.me/254$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          _showLogActivityDialog('SMS/WhatsApp');
        }
      }
    }
  }

  Future<void> _showLogActivityDialog(String type) async {
    final controller = TextEditingController();
    final outcomeController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Log $type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: outcomeController,
                  decoration: const InputDecoration(
                    labelText: 'Outcome (e.g., Answered, Left Message)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  try {
                    await _supabase.from('opportunity_activities').insert({
                      'school_id': widget.schoolId,
                      'opportunity_id': _activeSale?['id'],
                      'activity_type': type,
                      'activity_outcome': outcomeController.text,
                      'notes': controller.text,
                      'actor_id': _supabase.auth.currentUser?.id,
                    });
                    if (mounted) Navigator.pop(this.context);
                    _fetchData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Failed to log activity: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _launchEmail() async {
    final email = _schoolData!['email'] ?? 'school@example.com';
    final uri = Uri.parse('mailto:$email?subject=Follow-up from Dehus');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (mounted) {
        final log = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Log Email?'),
                content: const Text(
                  'Would you like to log this email to the timeline?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        );
        if (log == true) {
          _showLogActivityDialog('Email');
        }
      }
    }
  }
}
