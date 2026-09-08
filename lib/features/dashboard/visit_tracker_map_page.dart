import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/widgets/map_tile_controls.dart';

class VisitTrackerMapPage extends StatefulWidget {
  final Position? currentPosition;
  final DateTime? checkInTime;

  const VisitTrackerMapPage({
    super.key,
    this.currentPosition,
    this.checkInTime,
  });

  @override
  State<VisitTrackerMapPage> createState() => _VisitTrackerMapPageState();
}

class _VisitTrackerMapPageState extends State<VisitTrackerMapPage> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
    _loadHistory();
    _refreshCurrentLocation();
  }

  Future<void> _refreshCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() => _currentPosition = position);
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _supabase
          .from('visit_checkins')
          .select(
            'id, checkin_at, checkout_at, gps_lat, gps_lng, location_text, duration_seconds, auto_checkout',
          )
          .eq('agent_id', userId)
          .order('checkin_at', ascending: false)
          .limit(30);
      if (!mounted) return;
      setState(() {
        _history = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _focusOn(LatLng point, double zoom) {
    _mapController.move(point, zoom);
  }

  LatLng _getInitialCenter() {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    final firstWithCoords = _history.firstWhere(
      (r) => r['gps_lat'] != null && r['gps_lng'] != null,
      orElse: () => {},
    );
    if (firstWithCoords.isNotEmpty) {
      return LatLng(
        (firstWithCoords['gps_lat'] as num).toDouble(),
        (firstWithCoords['gps_lng'] as num).toDouble(),
      );
    }
    return const LatLng(-1.286389, 36.817223);
  }

  @override
  Widget build(BuildContext context) {
    final center = _getInitialCenter();
    final hasActiveSession = widget.checkInTime != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Visit Tracker Map'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'My location',
            onPressed: _refreshCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasActiveSession)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    size: 12,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Active session since ${_formatDateTime(widget.checkInTime!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 320,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 13.0),
              children: [
                MapTileLayer(
                  userAgentPackageName: 'com.longhorn.dehus',
                ),
                if (_history.isNotEmpty) _buildHistoryMarkers(),
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 60,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Recent Check-Ins',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_history.length} records',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _history.isEmpty
                    ? const Center(
                      child: Text(
                        'No check-in history yet.\nUse the Check-In page to record your first visit.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final record = _history[index];
                        return _buildHistoryTile(record, index);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryMarkers() {
    final markers = <Marker>[];
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      if (r['gps_lat'] == null || r['gps_lng'] == null) continue;
      final point = LatLng(
        (r['gps_lat'] as num).toDouble(),
        (r['gps_lng'] as num).toDouble(),
      );
      markers.add(
        Marker(
          point: point,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _focusOn(point, 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.history,
                color:
                    r['checkout_at'] != null
                        ? AppColors.primaryGreen
                        : AppColors.accentOrange,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }
    return MarkerLayer(markers: markers);
  }

  Widget _buildHistoryTile(Map<String, dynamic> record, int index) {
    final checkinAt =
        record['checkin_at'] != null
            ? DateTime.parse(record['checkin_at'] as String).toLocal()
            : null;
    final checkoutAt =
        record['checkout_at'] != null
            ? DateTime.parse(record['checkout_at'] as String).toLocal()
            : null;
    final isOpen = checkoutAt == null;
    final duration = record['duration_seconds'] as int?;
    final auto = record['auto_checkout'] == true;

    Color statusColor =
        isOpen ? AppColors.accentOrange : AppColors.primaryGreen;
    String statusText =
        isOpen ? 'ACTIVE' : (auto ? 'AUTO CHECK-OUT' : 'COMPLETED');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(
          isOpen ? Icons.play_arrow : Icons.check,
          color: statusColor,
        ),
      ),
      title: Text(
        checkinAt != null ? _formatDateTime(checkinAt) : 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record['location_text'] != null)
            Text(
              record['location_text'] as String,
              style: const TextStyle(fontSize: 12),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (duration != null)
                Text(
                  '· ${_formatDuration(duration)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.map_outlined, color: AppColors.primaryGreen),
        onPressed: () {
          if (record['gps_lat'] != null && record['gps_lng'] != null) {
            _focusOn(
              LatLng(
                (record['gps_lat'] as num).toDouble(),
                (record['gps_lng'] as num).toDouble(),
              ),
              16.0,
            );
          }
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
