import 'dart:async';
import 'dart:io';

import 'register_page.dart';
import 'admin_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/colors.dart';
import '../../admin/admin_dashboard_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../admin/admin_dashboard_screen.dart';
import '../../../services/api_service.dart';
import '../../../core/constants/bas_dashboard_page.dart';
import '../../../core/constants/agent_dashboard_page.dart';
import '../../profile/profile_page.dart';
import 'reset_password_page.dart';

class DeHeusLogin extends StatefulWidget {
  const DeHeusLogin({super.key});

  @override
  State<DeHeusLogin> createState() => _DeHeusLoginState();
}

class _DeHeusLoginState extends State<DeHeusLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _friendlyErrorMessage(Object error) {
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (error is TimeoutException) {
      return 'Connection timed out. Please try again.';
    }
    return ApiService().authErrorMessage(error);
  }

  Future<void> _loginUser() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final authResponse = await ApiService().login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final userData = Map<String, dynamic>.from(authResponse['user'] as Map);
      {
        final metadataRole = userData['role']?.toString();
        final dbRole = int.tryParse(metadataRole ?? '');

        if (!mounted) return;
        final resolvedRole =
            dbRole ??
            int.tryParse(metadataRole ?? '') ??
            (metadataRole?.toLowerCase() == 'admin' ? 1 : null) ??
            5;

        // DEBUG: Check what values are being read upon login
        debugPrint('--- LOGIN DEBUG ---');
        debugPrint('Auth Metadata Role: $metadataRole');
        debugPrint('Public DB Role: $dbRole');
        debugPrint('Final Resolved Role: $resolvedRole');
        debugPrint('-------------------');

        Widget destination;
        switch (resolvedRole) {
          case 1:
            destination = const AdminDashboardPage();
            break;
          case 2:
            destination = const AdminDashboardScreen();
            break;
          case 3:
            destination = const BasDashboardPage();
            break;
          case 4:
            destination = const AgentDashboardPage();
            break;
          case 5:
            destination =
                const SalesDashboard(); // SalesDashboard serves as the Grounds Operation dashboard
            break;
          default:
            destination = const SalesDashboard();
            break;
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => destination),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAdminLogin() async {
    if (kIsWeb) {
      final adminUrl = Uri.base.replace(path: '/admin-login');
      final launched = await launchUrl(adminUrl, webOnlyWindowName: '_blank');
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the admin login page.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primaryGreen],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryGreen.withValues(alpha: 0.85),
                AppColors.textDark.withValues(alpha: 0.95),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final isTablet = screenWidth >= 768;
                final isDesktop = screenWidth >= 1100;
                final contentWidth =
                    isDesktop ? 560.0 : (isTablet ? 520.0 : double.infinity);
                final horizontalPadding =
                    isDesktop ? 40.0 : (isTablet ? 32.0 : 22.0);
                final minContentHeight = isTablet ? constraints.maxHeight : 0.0;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: contentWidth,
                        minHeight: minContentHeight,
                      ),
                      child: Column(
                        mainAxisAlignment:
                            isTablet
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                        children: [
                          SizedBox(height: isTablet ? 24 : 52),
                          const Icon(
                            Icons.menu_book,
                            size: 60,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Commercial Team Portal",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.surfaceWhite,
                              fontSize: isTablet ? 32 : 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const Text(
                            "Log in to manage commercial accounts and publication workflows",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primaryPale,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: isTablet ? 44 : 34),
                          _buildLoginCard(),
                          const SizedBox(height: 30),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DeHeusRegister(),
                                ),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Register here",
                              style: TextStyle(
                                color: AppColors.primaryPale,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openAdminLogin,
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              label: const Text('Login as Admin'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryPale,
                                side: const BorderSide(
                                  color: AppColors.primaryLight,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isTablet ? 0 : 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.primaryGreen,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.primaryGreen,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed:
                    () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderGrey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ResetPasswordPage(),
                          ),
                        );
                      },
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: _isLoading ? null : _loginUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: AppColors.surfaceWhite,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text(
                      "SIGN IN",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
