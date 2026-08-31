import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/constants/colors.dart';
import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'features/welcome/welcome_page.dart';
import 'features/welcome/auth/login_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/welcome/auth/admin_login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/bas_dashboard_page.dart';
import 'core/constants/agent_dashboard_page.dart';
import 'features/profile/profile_page.dart';
import 'features/welcome/auth/reset_password_page.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/github_release_service.dart';
import 'dart:async';

// Event module pages
import 'features/events/events_list_page.dart';
import 'features/events/event_create_page.dart';
import 'features/events/event_detail_page.dart';
import 'features/events/event_assignments_page.dart';
import 'features/events/event_checkin_page.dart';
import 'features/events/event_tasks_page.dart';
import 'features/events/event_leads_page.dart';
import 'features/events/event_photos_page.dart';
import 'features/events/event_expenses_page.dart';
import 'features/events/event_reports_page.dart';
import 'features/events/event_samples_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  runApp(const DeHeusApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool _isPasswordResetLink(Uri uri) {
  if (kIsWeb) {
    return uri.path == '/reset-password';
  }
  return uri.scheme == 'dehus' && uri.host == 'reset-password';
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final uri = Uri.tryParse(settings.name ?? '');
  if (uri != null && _isPasswordResetLink(uri)) {
    String? code = uri.queryParameters['code'];
    String? accessToken = uri.queryParameters['access_token'];
    String? refreshToken = uri.queryParameters['refresh_token'];
    
    if (uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      code ??= fragmentParams['code'];
      accessToken ??= fragmentParams['access_token'];
      refreshToken ??= fragmentParams['refresh_token'];
    }

    return MaterialPageRoute(
      builder: (_) => ResetPasswordPage(
        code: code,
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
      settings: settings,
    );
  }
  return null;
}

class DeHeusApp extends StatelessWidget {
  const DeHeusApp({super.key, this.useRemoteHeroImage = true});

  final bool useRemoteHeroImage;
  static const Color _accentColor = Color(0xFF653A48);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Longhorn Publishers PLC',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: ui.PlatformDispatcher.instance.defaultRouteName,
      routes: {
        '/': (_) => const _SessionEntryPage(),
        '/login': (_) => const DeHeusLogin(),
        '/admin-login': (_) => const AdminLoginPage(),
        '/admin': (_) => const AdminDashboardPage(),
        // Event module
        '/events': (_) => const EventsListPage(),
        '/events/create': (_) => const EventCreatePage(),
        '/events/detail': (_) => const EventDetailPage(),
        '/events/assignments': (_) => const EventAssignmentsPage(),
        '/events/checkin': (_) => const EventCheckinPage(),
        '/events/tasks': (_) => const EventTasksPage(),
        '/events/leads': (_) => const EventLeadsPage(),
        '/events/photos': (_) => const EventPhotosPage(),
        '/events/expenses': (_) => const EventExpensesPage(),
        '/events/reports': (_) => const EventReportsPage(),
        '/events/samples': (_) => const EventSamplesPage(),
      },

      onGenerateRoute: _onGenerateRoute,

      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primaryGreen,
        scaffoldBackgroundColor: const Color(0xFFF6F3F1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.longhornMaroon,
          tertiary: _accentColor,
          surface: const Color(0xFFFDFBF9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.charcoalGrey),
          bodyMedium: TextStyle(color: AppColors.charcoalGrey),
        ),
      ),
    );
  }
}

class _SessionEntryPage extends StatefulWidget {
  const _SessionEntryPage();

  @override
  State<_SessionEntryPage> createState() => _SessionEntryPageState();
}

class _SessionEntryPageState extends State<_SessionEntryPage> {
  final _supabase = Supabase.instance.client;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;
  bool _loading = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolveStartupDestination();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    _deepLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!_isPasswordResetLink(uri)) return;
      
      String? code = uri.queryParameters['code'];
      String? accessToken = uri.queryParameters['access_token'];
      String? refreshToken = uri.queryParameters['refresh_token'];
      
      if (uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        code ??= fragmentParams['code'];
        accessToken ??= fragmentParams['access_token'];
        refreshToken ??= fragmentParams['refresh_token'];
      }

      if (mounted) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              code: code,
              accessToken: accessToken,
              refreshToken: refreshToken,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolveStartupDestination() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null && _isPasswordResetLink(initialUri)) {
      String? code = initialUri.queryParameters['code'];
      String? accessToken = initialUri.queryParameters['access_token'];
      String? refreshToken = initialUri.queryParameters['refresh_token'];
      
      if (initialUri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(initialUri.fragment);
        code ??= fragmentParams['code'];
        accessToken ??= fragmentParams['access_token'];
        refreshToken ??= fragmentParams['refresh_token'];
      }

      if (mounted) {
        setState(() {
          _destination = ResetPasswordPage(
            code: code,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          _loading = false;
        });
      }
      return;
    }

    final session = _supabase.auth.currentSession;
    if (session == null || session.user.id.isEmpty) {
      if (!mounted) return;
      setState(() {
        _destination = const WelcomePage();
        _loading = false;
      });
      _checkForUpdate();
      return;
    }

    try {
      final userId = session.user.id;
      final metadataRole = session.user.userMetadata?['role']?.toString();
      
      Map<String, dynamic>? userData;
      try {
        userData = await _supabase
            .from('users')
            .select('role')
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Timeout or network error, silently fallback to metadata
      }
      
      final dbRole = userData?['role'] as int?;
      final resolvedRole =
          dbRole ??
          int.tryParse(metadataRole ?? '') ??
          (metadataRole?.toLowerCase() == 'admin' ? 1 : null) ??
          5;

      Widget destination;
      // Roles 1-4 are admin area, role 5 is field agent
      if (resolvedRole == 5) {
        destination = const AgentDashboardPage();
      } else {
        destination = const AdminDashboardPage();
      }

      if (!mounted) return;
      setState(() {
        _destination = destination;
        _loading = false;
      });
      _checkForUpdate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destination = const WelcomePage();
        _loading = false;
      });
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final updateAvailable =
        await GithubReleaseService(
          owner: 'dehus',
          repo: 'dehus',
        ).isUpdateAvailable();

    if (!mounted || !updateAvailable) return;

    final release =
        await GithubReleaseService(
          owner: 'dehus',
          repo: 'dehus',
        ).fetchLatestRelease();
    if (!mounted || release == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
              'A new version (${release.tagName.replaceFirst(RegExp(r'^v'), '')}) is available.\n\nPlease update to get the latest features and bug fixes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    release.apkDownloadUrl ?? release.htmlUrl,
                  );
                  if (!await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open update link'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _destination == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _destination!;
  }
}
