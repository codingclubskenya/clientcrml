import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventExpensesPage extends StatefulWidget {
  const EventExpensesPage({super.key});

  @override
  State<EventExpensesPage> createState() => _EventExpensesPageState();
}

class _EventExpensesPageState extends State<EventExpensesPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;

  String? get _eventId =>
      ModalRoute.of(context)?.settings.arguments is Map
          ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
          : null;

  final _typeController = TextEditingController();
  final _amountController = TextEditingController();
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
      final expenses = await _dbService.getEventExpenses(id);
      setState(() => _expenses = expenses);
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

  Future<void> _addExpense() async {
    final id = _eventId;
    if (id == null) return;
    if (_typeController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter type and amount')),
      );
      return;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      await _dbService.createEventExpense({
        'event_id': id,
        'submitted_by': currentUser?.id,
        'expense_type': _typeController.text.trim(),
        'amount': double.tryParse(_amountController.text.trim()) ?? 0,
        'notes': _notesController.text.trim(),
        'status': 'pending',
      });
      _typeController.clear();
      _amountController.clear();
      _notesController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense added')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    _typeController.text = expense['expense_type']?.toString() ?? '';
    _amountController.text = expense['amount']?.toString() ?? '';
    _notesController.text = expense['notes']?.toString() ?? '';

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Expense'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
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

    if (result == true && _typeController.text.isNotEmpty) {
      try {
        await _supabase
            .from('event_expenses')
            .update({
              'expense_type': _typeController.text.trim(),
              'amount': double.tryParse(_amountController.text.trim()) ?? 0,
              'notes': _notesController.text.trim(),
            })
            .eq('id', expense['id']);
        _typeController.clear();
        _amountController.clear();
        _notesController.clear();
        _load();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text(
              'Delete ${expense['expense_type']} - KES ${expense['amount']}?',
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
        await _supabase.from('event_expenses').delete().eq('id', expense['id']);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense deleted')));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  double _calculateTotal() {
    return _expenses.fold<double>(0, (sum, e) {
      final amount = e['amount'];
      if (amount is num) return sum + amount.toDouble();
      return sum;
    });
  }

  @override
  void dispose() {
    _typeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Expenses'),
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
                            'Add New Expense',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _typeController,
                            decoration: const InputDecoration(
                              labelText: 'Expense Type',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Transport, Meals, Materials',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount (KES)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
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
                            onPressed: _addExpense,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Expense'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.green.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Expenses:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'KES ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_expenses.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No expenses recorded yet.'),
                      ),
                    )
                  else
                    ..._expenses.map((e) {
                      final status = e['status']?.toString() ?? 'pending';
                      Color statusColor;
                      switch (status) {
                        case 'approved':
                          statusColor = Colors.green;
                          break;
                        case 'rejected':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.orange;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withValues(alpha: 0.1),
                            child: Icon(
                              status == 'approved'
                                  ? Icons.check
                                  : Icons.pending,
                              color: statusColor,
                            ),
                          ),
                          title: Text(e['expense_type']?.toString() ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e['notes'] != null &&
                                  e['notes'].toString().isNotEmpty)
                                Text(e['notes'].toString()),
                              Text(
                                '${status.toUpperCase()} • ${EventDateFormat.format(e['created_at'])}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'KES ${e['amount'] ?? 0}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _editExpense(e);
                                  if (value == 'delete') _deleteExpense(e);
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
