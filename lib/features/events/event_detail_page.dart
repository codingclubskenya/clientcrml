import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database_service.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic>? _event;
  bool _loading = true;
  bool _canManage = false;

  String? get _eventId => ModalRoute.of(context)?.settings.arguments is Map
      ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
      : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _checkUserRole();
    });
  }

  Future<void> _checkUserRole() async {
    try {
      final role = await _dbService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _canManage = role <= 4 && role != 5;
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
      final row = await _supabase.from('events').select().eq('id', id).maybeSingle();
      if (row != null) setState(() => _event = Map<String, dynamic>.from(row));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed loading event: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openSubpage(String path) {
    Navigator.pushNamed(context, path, arguments: {'id': _eventId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_event?['name'] ?? 'Event'),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Assign Agent',
              icon: const Icon(Icons.person_add),
              onPressed: () => _openSubpage('/events/manage-assignments'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_event != null) ...[
                    Text(
                      _event!['name'] ?? '',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_event!['venue'] ?? ''} • ${_event!['region'] ?? ''}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildMenuGrid(),
                ],
              ),
            ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () => Navigator.pushNamed(context, '/events/reports', arguments: {'id': _eventId}),
              child: const Icon(Icons.picture_as_pdf),
            )
          : null,
    );
  }

  Widget _buildMenuGrid() {
    final menuItems = <_EventMenuItem>[
      if (_canManage)
        _EventMenuItem(
          'Assignments',
          Icons.people_outline,
          Colors.blue,
          '/events/manage-assignments',
        ),
      _EventMenuItem(
        'Check-ins',
        Icons.login,
        Colors.green,
        '/events/checkin',
      ),
      _EventMenuItem(
        'Tasks',
        Icons.checklist,
        Colors.orange,
        '/events/tasks',
      ),
      _EventMenuItem(
        'Leads',
        Icons.people,
        Colors.purple,
        '/events/leads',
      ),
      _EventMenuItem(
        'Orders',
        Icons.shopping_cart,
        Colors.teal,
        '/events/orders',
      ),
      _EventMenuItem(
        'Photos',
        Icons.photo_library,
        Colors.pink,
        '/events/photos',
      ),
      _EventMenuItem(
        'Expenses',
        Icons.receipt_long,
        Colors.red,
        '/events/expenses',
      ),
      _EventMenuItem(
        'Samples',
        Icons.inventory_2,
        Colors.amber,
        '/events/samples',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        return _buildMenuItem(item);
      },
    );
  }

  Widget _buildMenuItem(_EventMenuItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openSubpage(item.route),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 36, color: item.color),
            const SizedBox(height: 8),
            Text(
              item.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _EventMenuItem(this.title, this.icon, this.color, this.route);
}
