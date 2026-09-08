import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../database/database_service.dart';
import 'event_date_format.dart';

class EventCheckinPage extends StatefulWidget {
  const EventCheckinPage({super.key});

  @override
  State<EventCheckinPage> createState() => _EventCheckinPageState();
}

class _EventCheckinPageState extends State<EventCheckinPage> {
  final _supabase = Supabase.instance.client;
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _checkins = [];
  bool _loading = true;
  bool _hasCheckedIn = false;
  String? _lastCheckinId;

  String? get _eventId =>
      ModalRoute.of(context)?.settings.arguments is Map
          ? (ModalRoute.of(context)!.settings.arguments as Map)['id'] as String?
          : null;

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
      final checkins = await _dbService.getEventCheckins(id);
      final currentUserId = _supabase.auth.currentUser?.id;

      bool hasCheckedIn = false;
      String? lastCheckinId;

      for (final c in checkins) {
        if (c['agent_id'] == currentUserId && c['checkin_type'] == 'checkin') {
          hasCheckedIn = true;
          lastCheckinId = c['id']?.toString();
          break;
        }
      }

      setState(() {
        _checkins = checkins;
        _hasCheckedIn = hasCheckedIn;
        _lastCheckinId = lastCheckinId;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _takeSelfie() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) return null;

      final file = File(image.path);
      final fileName =
          'selfie_${DateTime.now().millisecondsSinceEpoch}_${image.name}';

      await _supabase.storage.from('event_selfies').upload(fileName, file);
      return _supabase.storage.from('event_selfies').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Selfie upload error: $e');
      return null;
    }
  }

  Future<void> _performCheckin() async {
    final id = _eventId;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        throw Exception('Could not get location');
      }

      final selfieUrl = await _takeSelfie();

      final currentUser = _supabase.auth.currentUser;
      await _dbService.checkinToEvent({
        'event_id': id,
        'agent_id': currentUser?.id,
        'gps_lat': position.latitude,
        'gps_lng': position.longitude,
        'geofence_verified': true,
        'selfie_url': selfieUrl,
        'checkin_type': 'checkin',
        'location_text': '${position.latitude}, ${position.longitude}',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Successfully checked in!')));
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Check-in failed: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _performCheckout() async {
    final id = _eventId;
    if (id == null) return;

    setState(() => _loading = true);
    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        throw Exception('Could not get location');
      }

      final selfieUrl = await _takeSelfie();

      final currentUser = _supabase.auth.currentUser;
      await _dbService.checkinToEvent({
        'event_id': id,
        'agent_id': currentUser?.id,
        'gps_lat': position.latitude,
        'gps_lng': position.longitude,
        'geofence_verified': true,
        'selfie_url': selfieUrl,
        'checkin_type': 'checkout',
        'location_text': '${position.latitude}, ${position.longitude}',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully checked out!')),
      );
      _load();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Check-out failed: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Check-ins'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildStatusCard(),
                  Expanded(
                    child:
                        _checkins.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _checkins.length,
                              itemBuilder: (ctx, i) {
                                final c = _checkins[i];
                                final user =
                                    c['users'] as Map<String, dynamic>?;
                                final name =
                                    user?['full_name']?.toString() ??
                                    user?['email']?.toString() ??
                                    'Unknown';
                                final type =
                                    c['checkin_type']?.toString() ?? 'checkin';
                                final time = EventDateFormat.format(
                                  c['checkin_at'],
                                );
                                final hasSelfie =
                                    c['selfie_url'] != null &&
                                    c['selfie_url'].toString().isNotEmpty;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          type == 'checkin'
                                              ? Colors.green.withValues(
                                                alpha: 0.1,
                                              )
                                              : Colors.orange.withValues(
                                                alpha: 0.1,
                                              ),
                                      child: Icon(
                                        type == 'checkin'
                                            ? Icons.login
                                            : Icons.logout,
                                        color:
                                            type == 'checkin'
                                                ? Colors.green
                                                : Colors.orange,
                                      ),
                                    ),
                                    title: Text(name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${type.toUpperCase()} • $time'),
                                        if (c['location_text'] != null)
                                          Text(
                                            'Location: ${c['location_text']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing:
                                        hasSelfie
                                            ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                            : null,
                                    isThreeLine: true,
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
      floatingActionButton:
          _loading
              ? null
              : FloatingActionButton.extended(
                onPressed: _hasCheckedIn ? _performCheckout : _performCheckin,
                icon: Icon(_hasCheckedIn ? Icons.logout : Icons.login),
                label: Text(_hasCheckedIn ? 'Check Out' : 'Check In'),
                backgroundColor: _hasCheckedIn ? Colors.orange : Colors.green,
              ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            _hasCheckedIn
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasCheckedIn ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _hasCheckedIn ? Icons.check_circle : Icons.schedule,
            color: _hasCheckedIn ? Colors.green : Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasCheckedIn ? 'You are checked in' : 'Not checked in',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _hasCheckedIn ? Colors.green : Colors.orange,
                  ),
                ),
                Text(
                  _hasCheckedIn
                      ? 'Tap the button below to check out when done'
                      : 'Tap the button below to check in with GPS verification',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No check-ins yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to check in!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
