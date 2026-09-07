import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';
import '../../core/constants/colors.dart';
import '../../models/consignment_model.dart';
import '../../models/user_model.dart';
import '../../services/catalog_service.dart';
import '../consignments/consignment_list_screen.dart';

class EventOrdersPage extends StatefulWidget {
  const EventOrdersPage({super.key});

  @override
  State<EventOrdersPage> createState() => _EventOrdersPageState();
}

class _EventOrdersPageState extends State<EventOrdersPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _eventOrders = [];
  List<Map<String, dynamic>> _availableOrders = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _sales = [];
  UserModel? _currentUserModel;
  bool _loading = true;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map
      ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
      : null;

  CatalogService get _catalog => CatalogService.instance;

  String _consignmentStatusLabel(ConsignmentStatus status) {
    switch (status) {
      case ConsignmentStatus.pending:
        return 'Pending';
      case ConsignmentStatus.active:
        return 'Active';
      case ConsignmentStatus.completed:
        return 'Completed';
      case ConsignmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Best-effort display name for the current user. Used as the
  /// business-associate key when validating stock against the
  /// local consignment service.
  String? get _currentBusinessAssociateId =>
      _currentUserModel?.id ?? _supabase.auth.currentUser?.id;

  String? get _currentBusinessAssociate {
    final user = _supabase.auth.currentUser;
    final name = _currentUserModel?.fullName ??
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString() ??
        user?.email?.split('@').first;
    return (name == null || name.isEmpty) ? null : name;
  }

  @override
  void initState() {
    super.initState();
    _catalog.addListener(_onCatalogChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _catalog.removeListener(_onCatalogChanged);
    super.dispose();
  }

  void _onCatalogChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final id = _eventId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final currentUser = _supabase.auth.currentUser;
      final currentUserModel = currentUser == null
          ? null
          : await _dbService.getUser(currentUser.id);
      final orders = await _dbService.getEventOrders(id);
      final available = await _getAvailableOrders(id);
      final products = await _loadProducts();
      final sales = await _loadSales(id);
      setState(() {
        _currentUserModel = currentUserModel;
        _eventOrders = orders;
        _availableOrders = available;
        _products = products;
        _sales = sales;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    // Merge the shared in-memory catalog (same source used by
    // /consignments and /catalog/products) with the Supabase
    // `catalog_items` table so event sales stay in sync.
    final serviceMap = <String, Map<String, dynamic>>{};
    for (final p in _catalog.products) {
      serviceMap[p.id] = {
        'id': p.id,
        'name': p.name,
        'sku': p.sku,
        'unit_price': p.unitPrice,
        'item_type': p.category,
        'current_stock': p.currentStock,
        'is_active': p.isActive,
        '_source': 'service',
      };
    }

    try {
      final data = await _supabase
          .from('catalog_items')
          .select('id, name, sku, unit_price, item_type')
          .eq('is_active', true)
          .order('name');
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (serviceMap.containsKey(id)) {
          // Prefer service entry (which has the latest stock / price
          // updated by consignment sales) but keep DB metadata.
          serviceMap[id] = {...serviceMap[id]!, ...row};
        } else {
          serviceMap[id] = {...row, '_source': 'supabase'};
        }
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
    return serviceMap.values.toList();
  }

  Future<List<Map<String, dynamic>>> _loadSales(String eventId) async {
    try {
      final data = await _supabase
          .from('event_sales')
          .select('*, catalog_items(name, sku), users(full_name)')
          .eq('event_id', eventId)
          .order('sold_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        debugPrint(
          'event_sales table is missing from the current Supabase schema. '
          'Apply supabase/schema_updates_event_sales.sql.',
        );
      } else {
        debugPrint('Error loading sales: $e');
      }
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableOrders(String eventId) async {
    try {
      final linkedOrderIds = await _supabase
          .from('event_orders')
          .select('order_id')
          .eq('event_id', eventId);

      final linkedIds = (linkedOrderIds as List)
          .map((e) => e['order_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      var query = _supabase
          .from('orders')
          .select('id, order_number, school_id, checkout_amount, status, created_at, schools(name)')
          .order('created_at', ascending: false)
          .limit(50);

      final data = await query;
      final allOrders = List<Map<String, dynamic>>.from(data);

      return allOrders
          .where((o) => !linkedIds.contains(o['id']?.toString()))
          .toList();
    } catch (e) {
      debugPrint('Error loading available orders: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _linkOrder(String orderId) async {
    final eventId = _eventId;
    if (eventId == null) return;

    try {
      final currentUser = _supabase.auth.currentUser;
      await _dbService.linkOrderToEvent({
        'event_id': eventId,
        'order_id': orderId,
        'agent_id': currentUser?.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order linked to event')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to link order: $e')),
        );
      }
    }
  }

  Future<void> _unlinkOrder(String eventOrderId) async {
    try {
      await _supabase.from('event_orders').delete().eq('id', eventOrderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order unlinked from event')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlink: $e')),
        );
      }
    }
  }

  Future<void> _showRecordSaleDialog() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available')),
      );
      return;
    }

    final sellerId = _currentBusinessAssociateId;
    final sellerName = _currentBusinessAssociate;
    final sellerLabel = sellerName ?? sellerId;

    // Filter to products that are both in stock and still allocated
    // to the current seller's consignment.
    final sellable = _products.where((p) {
      final id = p['id']?.toString() ?? '';
      if (id.isEmpty) return false;
      final stock = p['current_stock'];
      if (stock is num && stock <= 0) return false;
      final live = _catalog.productById(id);
      if (live == null || live.currentStock <= 0) return false;
      final remaining = _catalog.remainingAllocationFor(
        businessAssociateId: sellerId,
        businessAssociateName: sellerName,
        productId: id,
      );
      return remaining > 0;
    }).toList();

    if (sellable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No products are assigned to your consignment yet.',
          ),
        ),
      );
      return;
    }

    String? selectedProductId;
    final quantityController = TextEditingController(text: '1');
    final amountController = TextEditingController();
    String paymentMethod = 'cash';
    final notesController = TextEditingController();
    bool oversellWarning = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          int? remainingForSelected() {
            if (selectedProductId == null) return null;
            if (sellerId == null && sellerName == null) return null;
            return _catalog.remainingAllocationFor(
              businessAssociateId: sellerId,
              businessAssociateName: sellerName,
              productId: selectedProductId!,
            );
          }

          void recomputeOversellWarning() {
            final r = remainingForSelected();
            final qty = int.tryParse(quantityController.text) ?? 0;
            oversellWarning = r != null && qty > r;
          }

          void recomputeAmount() {
            final id = selectedProductId;
            if (id == null) return;
            Map<String, dynamic>? product;
            for (final p in _products) {
              if (p['id']?.toString() == id) {
                product = p;
                break;
              }
            }
            final price = product?['unit_price'];
            final qty = int.tryParse(quantityController.text) ?? 1;
            if (price is num) {
              amountController.text = (price * qty).toStringAsFixed(0);
            }
          }

          return AlertDialog(
            title: const Text('Record Sale'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sellerLabel != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_ind_outlined,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Linked to consignment for: $sellerLabel',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text('Product:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Select product',
                    ),
                    items: sellable.map((p) {
                      final name = p['name']?.toString() ?? 'Unknown';
                      final price = p['unit_price']?.toString() ?? '0';
                      final stock = p['current_stock'];
                      final stockLabel =
                          stock is num ? ' • stock $stock' : '';
                      return DropdownMenuItem(
                        value: p['id']?.toString(),
                        child: Text(
                          '$name (KES $price$stockLabel)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedProductId = val;
                        oversellWarning = false;
                        recomputeAmount();
                        recomputeOversellWarning();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      helperText: (() {
                        final r = remainingForSelected();
                        if (r == null) return null;
                        return 'Consignment remaining: $r';
                      })(),
                      errorText: oversellWarning
                          ? 'Exceeds available consignment allocation'
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      setDialogState(() {
                        recomputeAmount();
                        recomputeOversellWarning();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  const Text('Payment Method:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Cash'),
                          value: 'cash',
                          groupValue: paymentMethod,
                          onChanged: (val) =>
                              setDialogState(() => paymentMethod = val!),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Mpesa'),
                          value: 'mpesa',
                          groupValue: paymentMethod,
                          onChanged: (val) =>
                              setDialogState(() => paymentMethod = val!),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedProductId != null &&
                        amountController.text.isNotEmpty &&
                        !oversellWarning
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Record Sale'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && selectedProductId != null) {
      final qty = int.tryParse(quantityController.text) ?? 1;
      final updated = await _recordSale(
        selectedProductId!,
        qty,
        double.tryParse(amountController.text) ?? 0,
        paymentMethod,
        notesController.text.trim(),
      );
      if (!updated && sellerLabel != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sale not recorded: exceeds available consignment allocation.',
              ),
            ),
          );
        }
      }
    }
  }

  /// Returns `true` if the sale was successfully recorded against
  /// the user's consignment allocation and Supabase. When the user
  /// has no active consignment for the product, or the requested
  /// quantity exceeds the remaining allocation, the sale is rejected.
  Future<bool> _recordSale(
    String productId,
    int quantity,
    double amount,
    String paymentMethod,
    String notes,
  ) async {
    final eventId = _eventId;
    if (eventId == null) return false;

    final sellerId = _currentBusinessAssociateId;
    final sellerName = _currentBusinessAssociate;
    final hasSeller = sellerId != null || sellerName != null;
    final consignmentUpdated = hasSeller
        ? _catalog.recordSale(
            businessAssociateId: sellerId,
            businessAssociateName: sellerName,
            productId: productId,
            units: quantity,
          )
        : null;

    if (hasSeller && consignmentUpdated == null) {
      // Allocation missing or insufficient. Bail out before writing
      // to Supabase so the rest of the system stays consistent.
      return false;
    }

    try {
      final currentUser = _supabase.auth.currentUser;
      await _supabase.from('event_sales').insert({
        'event_id': eventId,
        'product_id': productId,
        'agent_id': currentUser?.id,
        'quantity': quantity,
        'amount': amount,
        'payment_method': paymentMethod,
        'notes': notes,
        'sold_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded successfully')),
        );
      }
      _load();
      return true;
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST205') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sales table is not set up yet. Apply the event_sales migration.',
              ),
            ),
          );
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record sale: $e')),
        );
      }
      return false;
    }
  }

  double _calculateTotalRevenue() {
    double total = 0;
    for (final eo in _eventOrders) {
      final order = eo['orders'] as Map<String, dynamic>?;
      if (order != null) {
        final amount = order['checkout_amount'];
        if (amount is num) total += amount.toDouble();
      }
    }
    for (final sale in _sales) {
      final amount = sale['amount'];
      if (amount is num) total += amount.toDouble();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _calculateTotalRevenue();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Orders & Sales'),
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
              padding: const EdgeInsets.all(12),
              children: [
                _buildSummaryCard(totalRevenue),
                const SizedBox(height: 12),
                Card(
                  color: Colors.green.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: const Icon(Icons.add_shopping_cart, color: Colors.green),
                    title: const Text('Record New Sale', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Record a product sale with cash or Mpesa'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showRecordSaleDialog,
                  ),
                ),
                const SizedBox(height: 12),
                if (_sales.isNotEmpty) ...[
                  const Text('Recent Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._sales.map((sale) {
                    final product = sale['catalog_items'] as Map<String, dynamic>?;
                    final user = sale['users'] as Map<String, dynamic>?;
                    final paymentMethod = sale['payment_method']?.toString() ?? 'cash';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: paymentMethod == 'mpesa' ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                          child: Icon(
                            paymentMethod == 'mpesa' ? Icons.phone_android : Icons.money,
                            color: paymentMethod == 'mpesa' ? Colors.green : Colors.blue,
                          ),
                        ),
                        title: Text(product?['name']?.toString() ?? 'Product'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Qty: ${sale['quantity'] ?? 1} • ${paymentMethod.toUpperCase()}'),
                            if (user != null)
                              Text('By: ${user['full_name']}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: Text(
                          'KES ${sale['amount'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
                ExpansionTile(
                  title: const Text('Linked Consignments'),
                  leading: const Icon(Icons.inventory_2_outlined,
                      color: AppColors.primaryGreen),
                  children: _buildConsignmentChildren(),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  title: const Text('Linked Orders'),
                  leading: const Icon(Icons.link, color: Colors.blue),
                  children: _availableOrders.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No unlinked orders available'),
                          ),
                        ]
                      : _availableOrders.map((order) {
                          final school = order['schools'] as Map<String, dynamic>?;
                          return ListTile(
                            title: Text(order['order_number']?.toString() ?? 'Order'),
                            subtitle: Text(school?['name']?.toString() ?? ''),
                            trailing: Text(
                              'KES ${order['checkout_amount'] ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () => _linkOrder(order['id']?.toString() ?? ''),
                          );
                        }).toList(),
                ),
                const SizedBox(height: 12),
                if (_eventOrders.isNotEmpty) ...[
                  const Text('Event Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._eventOrders.map((eo) {
                    final order = eo['orders'] as Map<String, dynamic>?;
                    final user = eo['users'] as Map<String, dynamic>?;
                    final school = order?['schools'] as Map<String, dynamic>?;

                    if (order == null) return const SizedBox.shrink();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          child: const Icon(Icons.shopping_cart, color: Colors.green),
                        ),
                        title: Text(
                          order['order_number']?.toString() ?? 'Order',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (school != null) Text('School: ${school['name']}'),
                            Text('Status: ${order['status'] ?? 'unknown'}'),
                            if (user != null)
                              Text('Agent: ${user['full_name']}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'KES ${order['checkout_amount'] ?? 0}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _unlinkOrder(eo['id']?.toString() ?? ''),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecordSaleDialog,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Record Sale'),
      ),
    );
  }

  Widget _buildSummaryCard(double totalRevenue) {
    final totalOrders = _eventOrders.length + _sales.length;

    return Card(
      color: Colors.green.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '$totalOrders',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text('Total Sales', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            Column(
              children: [
                Text(
                  'KES ${_formatNumber(totalRevenue)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text('Revenue', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConsignmentChildren() {
    final ba = _currentBusinessAssociate;
    final List<Consignment> consignments = ba == null
        ? <Consignment>[]
        : _catalog.consignments
            .where((c) =>
                (c.businessAssociateId == _currentBusinessAssociateId ||
                    c.businessAssociateName.trim().toLowerCase() ==
                        ba.trim().toLowerCase()) &&
                c.status != ConsignmentStatus.cancelled)
            .toList();

    if (consignments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ba == null
                    ? 'Sign in to view linked consignments.'
                    : 'No active consignment for $ba.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConsignmentListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Manage consignments'),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      ...consignments.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.consignmentId,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(_consignmentStatusLabel(c.status),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primaryGreen)),
                ],
              ),
              const SizedBox(height: 4),
              ...c.items.map((i) => Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '${i.unitsSold}/${i.unitsToAssign} sold',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 60,
                          child: LinearProgressIndicator(
                            value: i.progress,
                            minHeight: 4,
                            backgroundColor: Colors.grey.shade200,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      }),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConsignmentListScreen(),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open consignments'),
          ),
        ),
      ),
    ];
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
