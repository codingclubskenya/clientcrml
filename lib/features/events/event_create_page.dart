import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/colors.dart';
import '../database/database_service.dart';
import '../../models/event_model.dart';
import 'event_date_format.dart';

class EventCreatePage extends StatefulWidget {
  const EventCreatePage({super.key});

  @override
  State<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends State<EventCreatePage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _eventType = TextEditingController();
  final _organization = TextEditingController();
  final _venue = TextEditingController();
  final _expectedAttendance = TextEditingController();
  final _budget = TextEditingController();
  final _objectives = TextEditingController();
  final _notes = TextEditingController();

  String? _selectedRegion;
  String? _selectedSubregion;
  String? _selectedSchoolId;
  String _status = 'scheduled';

  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  List<String> _regions = [];
  List<Map<String, dynamic>> _subregions = [];
  List<Map<String, dynamic>> _schools = [];

  final List<Map<String, dynamic>> _products = [];
  final _productName = TextEditingController();
  final _productQty = TextEditingController();

  final List<Map<String, dynamic>> _targets = [];
  final _targetName = TextEditingController();
  final _targetValue = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _loadSchools();
  }

  Future<void> _loadRegions() async {
    try {
      final data = await _supabase
          .from('regions')
          .select('region, sub_region')
          .order('region')
          .order('sub_region');

      final regionSet = <String>{};
      final subregionList = <Map<String, dynamic>>[];

      for (final item in data as List) {
        final region = item['region']?.toString() ?? '';
        final subregion = item['sub_region']?.toString() ?? '';
        if (region.isNotEmpty) regionSet.add(region);
        if (subregion.isNotEmpty) {
          subregionList.add({'region': region, 'sub_region': subregion});
        }
      }

      setState(() {
        _regions = regionSet.toList()..sort();
        _subregions = subregionList;
      });
    } catch (e) {
      debugPrint('Error loading regions: $e');
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

  Future<void> _pickDate(BuildContext ctx, bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final time = await showTimePicker(
      context: ctx,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;
    final dt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _start = dt;
      } else {
        _end = dt;
      }
    });
  }

  void _addProduct() {
    if (_productName.text.isEmpty) return;
    setState(() {
      _products.add({
        'product': _productName.text.trim(),
        'qty': int.tryParse(_productQty.text.trim()) ?? 0,
      });
      _productName.clear();
      _productQty.clear();
    });
  }

  void _removeProduct(int index) {
    setState(() => _products.removeAt(index));
  }

  void _addTarget() {
    if (_targetName.text.isEmpty) return;
    setState(() {
      _targets.add({
        'name': _targetName.text.trim(),
        'value': double.tryParse(_targetValue.text.trim()) ?? 0,
      });
      _targetName.clear();
      _targetValue.clear();
    });
  }

  void _removeTarget(int index) {
    setState(() => _targets.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a start date/time')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'event_type': _eventType.text.trim(),
        'organization': _organization.text.trim(),
        'venue': _venue.text.trim(),
        'region': _selectedRegion,
        'subregion': _selectedSubregion,
        'expected_attendance': int.tryParse(_expectedAttendance.text.trim()),
        'budget': double.tryParse(_budget.text.trim()),
        'objectives': _objectives.text.trim(),
        'notes': _notes.text.trim(),
        'status': _status,
        'products': _products,
        'created_by': currentUser?.id,
      };

      if (_start != null)
        payload['start_at'] = _start!.toUtc().toIso8601String();
      if (_end != null) payload['end_at'] = _end!.toUtc().toIso8601String();

      final eventId = await _dbService.createEvent(payload);

      if (eventId != null && _targets.isNotEmpty) {
        for (final target in _targets) {
          await _supabase.from('event_tasks').insert({
            'event_id': eventId,
            'title': 'Target: ${target['name']}',
            'description': 'Target value: ${target['value']}',
            'required': true,
            'completed': false,
          });
        }
      }

      if (mounted) Navigator.pop(context);
    } on PostgrestException catch (e) {
      debugPrint('Event insert error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: ${e.message}')));
      }
    } catch (e) {
      debugPrint('Save exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _eventType.dispose();
    _organization.dispose();
    _venue.dispose();
    _expectedAttendance.dispose();
    _budget.dispose();
    _objectives.dispose();
    _notes.dispose();
    _productName.dispose();
    _productQty.dispose();
    _targetName.dispose();
    _targetValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableSubregions =
        _subregions
            .where(
              (s) => _selectedRegion == null || s['region'] == _selectedRegion,
            )
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSectionHeader('Basic Information'),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Event Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _eventType,
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Activation, Exhibition, Workshop',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _organization,
                decoration: const InputDecoration(
                  labelText: 'Organization / Brand',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _venue,
                decoration: const InputDecoration(
                  labelText: 'Venue',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Location & Region'),
              DropdownButtonFormField<String?>(
                value: _selectedRegion,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select Region'),
                  ),
                  ..._regions.map(
                    (r) => DropdownMenuItem(value: r, child: Text(r)),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedRegion = val;
                    _selectedSubregion = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedSubregion,
                decoration: const InputDecoration(
                  labelText: 'Subregion',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select Subregion'),
                  ),
                  ...availableSubregions.map(
                    (s) => DropdownMenuItem(
                      value: s['sub_region'],
                      child: Text(s['sub_region']?.toString() ?? ''),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedSubregion = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _selectedSchoolId,
                decoration: const InputDecoration(
                  labelText: 'Link to School / Institution',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select School (Optional)'),
                  ),
                  ..._schools.map(
                    (s) => DropdownMenuItem(
                      value: s['id']?.toString(),
                      child: Text(s['name']?.toString() ?? ''),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedSchoolId = val),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Schedule'),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _start == null
                          ? 'Start Date/Time *'
                          : EventDateFormat.format(_start),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context, true),
                    child: const Text('Pick Start'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _end == null
                          ? 'End Date/Time'
                          : EventDateFormat.format(_end),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickDate(context, false),
                    child: const Text('Pick End'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Objectives & Targets'),
              TextFormField(
                controller: _objectives,
                decoration: const InputDecoration(
                  labelText: 'Event Objectives',
                  border: OutlineInputBorder(),
                  hintText: 'Describe the main goals of this event',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expectedAttendance,
                decoration: const InputDecoration(
                  labelText: 'Expected Attendance',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budget,
                decoration: const InputDecoration(
                  labelText: 'Budget (KES)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'scheduled',
                    child: Text('Scheduled'),
                  ),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                ],
                onChanged: (val) => setState(() => _status = val!),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Products to Promote'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _productName,
                      decoration: const InputDecoration(
                        hintText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _productQty,
                      decoration: const InputDecoration(
                        hintText: 'Qty',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addProduct,
                  ),
                ],
              ),
              if (_products.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      _products.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(
                            '${entry.value['product']} (${entry.value['qty']})',
                          ),
                          onDeleted: () => _removeProduct(entry.key),
                        );
                      }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              _buildSectionHeader('Sales Targets'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetName,
                      decoration: const InputDecoration(
                        hintText: 'Target name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _targetValue,
                      decoration: const InputDecoration(
                        hintText: 'Value',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addTarget,
                  ),
                ],
              ),
              if (_targets.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._targets.asMap().entries.map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(entry.value['name']?.toString() ?? ''),
                    trailing: Text('${entry.value['value']}'),
                    leading: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeTarget(entry.key),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              _buildSectionHeader('Additional Notes'),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Any additional information about the event',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _saving
                        ? const CircularProgressIndicator()
                        : const Text(
                          'Create Event',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.charcoalGrey,
        ),
      ),
    );
  }
}
