import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventSamplesPage extends StatefulWidget {
  const EventSamplesPage({super.key});

  @override
  State<EventSamplesPage> createState() => _EventSamplesPageState();
}

class _EventSamplesPageState extends State<EventSamplesPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _samples = [];
  bool _loading = true;

  String? get _eventId =>
      ModalRoute.of(context)?.settings.arguments is Map
          ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
          : null;

  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final samples = await _dbService.getEventSamples(id);
      setState(() => _samples = samples);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addSample() async {
    final id = _eventId;
    if (id == null) return;
    if (_productNameController.text.isEmpty ||
        _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter product and quantity')),
      );
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      await _dbService.createEventSample({
        'event_id': id,
        'distributed_by': currentUser?.id,
        'product_name': _productNameController.text.trim(),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
        'recipient': _recipientNameController.text.trim(),
        'notes': _notesController.text.trim(),
      });
      _productNameController.clear();
      _quantityController.clear();
      _recipientNameController.clear();
      _notesController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sample recorded')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  Future<void> _editSample(Map<String, dynamic> sample) async {
    _productNameController.text = sample['product_name']?.toString() ?? '';
    _quantityController.text = sample['quantity']?.toString() ?? '';
    _recipientNameController.text = sample['recipient']?.toString() ?? '';
    _notesController.text = sample['notes']?.toString() ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Sample'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _recipientNameController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result == true && _productNameController.text.isNotEmpty) {
      try {
        await _supabase
            .from('event_samples')
            .update({
              'product_name': _productNameController.text.trim(),
              'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
              'recipient': _recipientNameController.text.trim(),
              'notes': _notesController.text.trim(),
            })
            .eq('id', sample['id']);
        _productNameController.clear();
        _quantityController.clear();
        _recipientNameController.clear();
        _notesController.clear();
        _load();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _deleteSample(Map<String, dynamic> sample) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Sample'),
            content: Text(
              'Delete ${sample['quantity']}x ${sample['product_name']}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('event_samples').delete().eq('id', sample['id']);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sample deleted')));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  int _calculateTotalSamples() {
    return _samples.fold<int>(0, (sum, s) {
      final qty = s['quantity'];
      if (qty is int) return sum + qty;
      if (qty is num) return sum + qty.toInt();
      return sum;
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _recipientNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSamples = _calculateTotalSamples();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Distribution'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Record New Sample',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _productNameController,
                            decoration: const InputDecoration(
                              labelText: 'Product Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _recipientNameController,
                            decoration: const InputDecoration(
                              labelText: 'Recipient (Teacher/Parent)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _addSample,
                            icon: const Icon(Icons.add),
                            label: const Text('Record Sample'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.orange.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Samples Distributed:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$totalSamples',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_samples.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No samples distributed yet.'),
                      ),
                    )
                  else
                    ..._samples.map((s) {
                      final user = s['users'] as Map<String, dynamic>?;
                      final agentName = user?['full_name']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(
                              Icons.inventory,
                              color: Colors.orange,
                            ),
                          ),
                          title: Text('${s['quantity']}x ${s['product_name']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s['recipient'] != null)
                                Text('Recipient: ${s['recipient']}'),
                              if (s['notes'] != null &&
                                  s['notes'].toString().isNotEmpty)
                                Text(s['notes'].toString()),
                              if (agentName.isNotEmpty)
                                Text(
                                  'By: $agentName • ${EventDateFormat.format(s['distributed_at'])}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editSample(s);
                              if (value == 'delete') _deleteSample(s);
                            },
                            itemBuilder:
                                (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }),
                ],
              ),
    );
  }
}
