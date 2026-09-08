import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/colors.dart';

class ClockInPage extends StatefulWidget {
  const ClockInPage({super.key});

  @override
  State<ClockInPage> createState() => _ClockInPageState();
}

class _ClockInPageState extends State<ClockInPage> {
  bool _isClockedIn = false;
  String _currentTime = "";
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    setState(() {
      _currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    });
  }

  void _toggleClock() {
    setState(() {
      _isClockedIn = !_isClockedIn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isClockedIn
              ? "Checked in successfully at the school"
              : "Checked out successfully",
        ),
        backgroundColor:
            _isClockedIn ? AppColors.primaryGreen : AppColors.secondaryOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.height < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("School Visit Tracking"),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                        fontSize: isSmallScreen ? 48 : 64,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),

                    SizedBox(height: screenSize.height * 0.05),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color:
                                        _isClockedIn
                                            ? AppColors.primaryGreen
                                            : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Location: ",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const Text(
                                    "Nairobi, Kenya",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 30),
                            Text(
                              _isClockedIn
                                  ? "STATUS: ON VISIT"
                                  : "STATUS: OFF VISIT",
                              style: TextStyle(
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                                color:
                                    _isClockedIn
                                        ? AppColors.primaryGreen
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: screenSize.height * 0.08),

                    _buildResponsiveClockButton(screenSize),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveClockButton(Size screenSize) {
    double diameter = (screenSize.height * 0.25).clamp(160.0, 240.0);

    return GestureDetector(
      onTap: _toggleClock,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: diameter,
        width: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: (_isClockedIn
                      ? AppColors.secondaryOrange
                      : AppColors.primaryGreen)
                  .withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
          border: Border.all(
            color:
                _isClockedIn
                    ? AppColors.secondaryOrange
                    : AppColors.primaryGreen,
            width: diameter * 0.04,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isClockedIn ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: diameter * 0.4,
              color:
                  _isClockedIn
                      ? AppColors.secondaryOrange
                      : AppColors.primaryGreen,
            ),
            Text(
              _isClockedIn ? "CHECK OUT" : "CHECK IN",
              style: TextStyle(
                fontSize: diameter * 0.08,
                fontWeight: FontWeight.bold,
                color:
                    _isClockedIn
                        ? AppColors.secondaryOrange
                        : AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
