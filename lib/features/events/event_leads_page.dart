import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';

class EventLeadsPage extends StatefulWidget {
  const EventLeadsPage({super.key});

  @override
  State<EventLeadsPage> createState() => _EventLeadsPageState();
}

class _EventLeadsPageState extends State<EventLeadsPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _leads = [];
  List<Map<String, dynamic>> _schools = [];
  bool _loading = true;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map
      ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
      : null;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _products = TextEditingController();
  final _timeline = TextEditingController();
  final _notes = TextEditingController();
  String? _selectedSchoolId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _loadSchools();
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final leads = await _dbService.getEventLeads(id);
      setState(() => _leads = leads);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSchools() async {
    try {
      final data = await _supabase
          .from('schools')
          .select('id, name, county, region')
          .order('name')
          .limit(500);

      setState(() {
        _schools = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading schools: $e');
    }
  }

  Future<void> _createLead() async {
    final id = _eventId;
    if (id == null) return;
    if (_name.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter lead name')),
      );
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      await _dbService.createEventLead({
        'event_id': id,
        'agent_id': currentUser?.id,
        'lead_name': _name.text.trim(),
        'school_id': _selectedSchoolId,
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'interested_products': _products.text.trim().isNotEmpty
            ? _products.text.trim().split(',').map((e) => e.trim()).toList()
            : [],
        'purchase_timeline': _timeline.text.trim(),
        'notes': _notes.text.trim(),
      });

      _name.clear();
      _phone.clear();
      _email.clear();
      _products.clear();
      _timeline.clear();
      _notes.clear();
      _selectedSchoolId = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead captured successfully')),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _products.dispose();
    _timeline.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Leads'),
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
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                _buildSummaryCard(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ExpansionTile(
                    title: const Text('Add New Lead'),
                    leading: const Icon(Icons.person_add, color: Colors.green),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Lead Name *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _selectedSchoolId,
                              decoration: const InputDecoration(
                                labelText: 'School / Institution',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Select School (Optional)')),
                                ..._schools.map((s) => DropdownMenuItem(
                                      value: s['id']?.toString(),
                                      child: Text(s['name']?.toString() ?? ''),
                                    )),
                              ],
                              onChanged: (val) => setState(() => _selectedSchoolId = val),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _email,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _products,
                              decoration: const InputDecoration(
                                labelText: 'Interested Products',
                                border: OutlineInputBorder(),
                                hintText: 'Comma-separated list',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _timeline.text.isEmpty ? null : _timeline.text,
                              decoration: const InputDecoration(
                                labelText: 'Purchase Timeline',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'immediate', child: Text('Immediate')),
                                DropdownMenuItem(value: '1_week', child: Text('Within 1 Week')),
                                DropdownMenuItem(value: '1_month', child: Text('Within 1 Month')),
                                DropdownMenuItem(value: '1_quarter', child: Text('Within 1 Quarter')),
                                DropdownMenuItem(value: 'future', child: Text('Future Consideration')),
                              ],
                              onChanged: (val) => _timeline.text = val ?? '',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notes,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _createLead,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Lead'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_leads.isEmpty)
                  _buildEmptyState()
                else
                  ..._leads.map((l) {
                    final school = l['schools'] as Map<String, dynamic>?;
                    final schoolName = school?['name']?.toString() ?? '';
                    final user = l['users'] as Map<String, dynamic>?;
                    final agentName = user?['full_name']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, color: Colors.purple),
                          ),
                          title: Text(
                            l['lead_name']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (l['phone'] != null) Text('Phone: ${l['phone']}'),
                              if (l['email'] != null) Text('Email: ${l['email']}'),
                              if (schoolName.isNotEmpty) Text('School: $schoolName', style: const TextStyle(fontSize: 12)),
                              if (agentName.isNotEmpty) Text('Captured by: $agentName', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    final totalLeads = _leads.length;
    final withPhone = _leads.where((l) => l['phone'] != null && l['phone'].toString().isNotEmpty).length;
    final withEmail = _leads.where((l) => l['email'] != null && l['email'].toString().isNotEmpty).length;
    final withSchool = _leads.where((l) => l['school_id'] != null).length;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total', '$totalLeads', Colors.purple),
          _buildSummaryItem('With Phone', '$withPhone', Colors.blue),
          _buildSummaryItem('With Email', '$withEmail', Colors.green),
          _buildSummaryItem('With School', '$withSchool', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No leads captured yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the form above to add leads',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
