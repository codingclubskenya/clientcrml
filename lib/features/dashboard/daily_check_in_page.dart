import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../core/constants/colors.dart';
import 'visit_tracker_map_page.dart';

class DailyCheckInPage extends StatefulWidget {
  const DailyCheckInPage({super.key});

  @override
  State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  static const Duration _maxShiftDuration = Duration(hours: 5);

  bool _isClockedIn = false;
  bool _isLoadingLocation = false;
  String _currentTime = "";
  String? _locationError;
  Position? _currentPosition;
  DateTime? _checkInTime;
  Duration _elapsed = Duration.zero;
  late Timer _timer;
  Timer? _autoCheckOutTimer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );
    _restoreActiveSession();
  }

  @override
  void dispose() {
    _timer.cancel();
    _autoCheckOutTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        if (_checkInTime != null) {
          _elapsed = now.difference(_checkInTime!);
        }
      });
    }
  }

  Future<void> _restoreActiveSession() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final response =
          await Supabase.instance.client
              .from('visit_checkins')
              .select('id, checkin_at')
              .eq('agent_id', userId)
              .isFilter('checkout_at', null)
              .order('checkin_at', ascending: false)
              .limit(1)
              .maybeSingle();
      if (response != null && mounted) {
        final start =
            DateTime.parse(response['checkin_at'] as String).toLocal();
        setState(() {
          _isClockedIn = true;
          _checkInTime = start;
          _elapsed = DateTime.now().difference(start);
        });
        _scheduleAutoCheckOut();
      }
    } catch (_) {}
  }

  Future<Position?> _getCurrentPosition() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Please enable location services.';
          _isLoadingLocation = false;
        });
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission is required to check in.';
          _isLoadingLocation = false;
        });
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return null;
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      return position;
    } catch (_) {
      if (!mounted) return null;
      setState(() {
        _locationError = 'Could not get your location. Please try again.';
        _isLoadingLocation = false;
      });
      return null;
    }
  }

  void _scheduleAutoCheckOut() {
    _autoCheckOutTimer?.cancel();
    if (_checkInTime == null) return;
    final remaining = _maxShiftDuration - _elapsed;
    if (remaining.isNegative || remaining == Duration.zero) {
      _performAutoCheckOut();
      return;
    }
    _autoCheckOutTimer = Timer(remaining, _performAutoCheckOut);
  }

  Future<void> _performAutoCheckOut() async {
    if (!_isClockedIn) return;
    await _saveCheckOut(autoTriggered: true);
  }

  Future<void> _toggleClock() async {
    if (_isClockedIn) {
      if (_checkInTime != null) {
        final elapsed = DateTime.now().difference(_checkInTime!);
        if (elapsed < _maxShiftDuration) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Check-out is locked until ${_maxShiftDuration.inHours} hours have passed. '
                'Time remaining: ${_formatElapsed(_maxShiftDuration - elapsed)}.',
              ),
              backgroundColor: AppColors.accentOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
      await _saveCheckOut(autoTriggered: false);
    } else {
      final position = await _getCurrentPosition();
      if (position == null) return;
      await _saveCheckIn(position);
    }
  }

  Future<void> _saveCheckIn(Position position) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final now = DateTime.now();
    setState(() {
      _isClockedIn = true;
      _checkInTime = now;
      _elapsed = Duration.zero;
    });

    _scheduleAutoCheckOut();

    try {
      final profile =
          await Supabase.instance.client
              .from('users')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();
      final agentName = profile?['full_name']?.toString();

      await Supabase.instance.client.from('visit_checkins').insert({
        'agent_id': userId,
        'agent_name': agentName,
        'checkin_at': now.toUtc().toIso8601String(),
        'gps_lat': position.latitude,
        'gps_lng': position.longitude,
        'location_text':
            'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}',
        'notes': 'Daily check-in',
      });
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Checked in successfully.'),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveCheckOut({required bool autoTriggered}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final position = await _getCurrentPosition();
    final checkInTime = _checkInTime;
    final checkoutTime = DateTime.now();
    final duration =
        checkInTime != null
            ? checkoutTime.difference(checkInTime).inSeconds
            : 0;

    setState(() {
      _isClockedIn = false;
      _checkInTime = null;
      _elapsed = Duration.zero;
    });
    _autoCheckOutTimer?.cancel();

    try {
      if (checkInTime != null) {
        await Supabase.instance.client
            .from('visit_checkins')
            .update({
              'checkout_at': checkoutTime.toUtc().toIso8601String(),
              'gps_lat': position?.latitude,
              'gps_lng': position?.longitude,
              'location_text':
                  position == null
                      ? 'Location unavailable'
                      : 'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}',
              'duration_seconds': duration,
              'auto_checkout': autoTriggered,
              'notes':
                  autoTriggered
                      ? 'Auto check-out after ${_maxShiftDuration.inHours}h'
                      : 'Manual check-out',
            })
            .eq('agent_id', userId)
            .isFilter('checkout_at', null);
      }
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          autoTriggered
              ? 'Auto checked out after ${_maxShiftDuration.inHours} hours.'
              : 'Checked out successfully.',
        ),
        backgroundColor:
            autoTriggered ? AppColors.accentOrange : AppColors.secondaryOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Duration _remainingTime() {
    if (_checkInTime == null) return _maxShiftDuration;
    final elapsed = DateTime.now().difference(_checkInTime!);
    final remaining = _maxShiftDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _openMap() async {
    if (_currentPosition == null) {
      await _getCurrentPosition();
    }
    if (_currentPosition == null) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => VisitTrackerMapPage(
              currentPosition: _currentPosition,
              checkInTime: _checkInTime,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.height < 700;
    final remaining = _remainingTime();
    final remainingFormatted =
        '${remaining.inHours.toString().padLeft(2, '0')}:${(remaining.inMinutes % 60).toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Daily Check-In / Out"),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'View on map',
            onPressed: _openMap,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Text(
                      DateTime.now().toString().split(' ')[0],
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _currentTime,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 40 : 56,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.02),
                    _buildMapPreview(isSmallScreen),
                    SizedBox(height: screenSize.height * 0.02),
                    _buildStatusCard(remainingFormatted, remaining),
                    SizedBox(height: screenSize.height * 0.03),
                    _buildResponsiveClockButton(screenSize),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapPreview(bool isSmallScreen) {
    final center =
        _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(-1.286389, 36.817223);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _openMap,
        child: Container(
          height: isSmallScreen ? 160 : 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.longhorn.dehus',
                  ),
                  if (_currentPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: center,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 50,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (_isLoadingLocation)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full, size: 14, color: Colors.black87),
                      SizedBox(width: 4),
                      Text(
                        'Tap to expand',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentPosition == null && !_isLoadingLocation)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Tap Check In to capture your location',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String remainingFormatted, Duration remaining) {
    String locationLabel = 'Unknown';
    if (_currentPosition != null) {
      locationLabel =
          'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(5)}';
    } else if (_locationError != null) {
      locationLabel = _locationError!;
    } else {
      locationLabel = 'Location not yet captured';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: _isClockedIn ? AppColors.primaryGreen : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text('Location: ', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Text(
                    locationLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isClockedIn ? 'ON DUTY' : 'OFF DUTY',
                      style: TextStyle(
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color:
                            _isClockedIn ? AppColors.primaryGreen : Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (_isClockedIn)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'ELAPSED',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatElapsed(_elapsed),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'MAX SHIFT',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_maxShiftDuration.inHours}h 00m',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (_isClockedIn) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AUTO CHECK-OUT IN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    remainingFormatted,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color:
                          remaining.inMinutes < 30
                              ? AppColors.accentOrange
                              : AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveClockButton(Size screenSize) {
    double diameter = (screenSize.height * 0.22).clamp(150.0, 220.0);
    final bool canCheckOut =
        _checkInTime == null ||
        DateTime.now().difference(_checkInTime!) >= _maxShiftDuration;
    final bool isLocked = _isClockedIn && !canCheckOut;
    final Color activeColor =
        isLocked
            ? Colors.grey
            : (_isClockedIn
                ? AppColors.secondaryOrange
                : AppColors.primaryGreen);

    return GestureDetector(
      onTap: (_isLoadingLocation || isLocked) ? null : _toggleClock,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: diameter,
        width: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
          border: Border.all(color: activeColor, width: diameter * 0.04),
        ),
        child:
            _isLoadingLocation
                ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLocked
                          ? Icons.lock_rounded
                          : (_isClockedIn
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded),
                      size: diameter * 0.4,
                      color: activeColor,
                    ),
                    Text(
                      isLocked
                          ? "LOCKED"
                          : (_isClockedIn ? "CHECK OUT" : "CHECK IN"),
                      style: TextStyle(
                        fontSize: diameter * 0.08,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
