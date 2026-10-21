import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/config/api_config.dart';
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userData;

  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  String get baseUrl => ApiConfig.baseUrl;

  /// Returns a useful server message for auth forms while avoiding the noisy
  /// DioException diagnostic dump shown by [Object.toString].
  String authErrorMessage(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map) {
        final message = responseData['error'] ?? responseData['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
      if (error.response?.statusCode == 401) return 'Invalid email or password.';
      if (error.response?.statusCode == 409) return 'This email is already registered.';
      if (error.response?.statusCode != null) {
        return 'Request failed (${error.response!.statusCode}). Please try again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Connection timed out. Please try again.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Could not reach the server. Check your internet connection.';
      }
    }
    return error.toString();
  }

  Future<void> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          try {
            await _refreshAccessToken();
            error.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {
            await logout();
          }
        }
        handler.next(error);
      },
    ));

    await _loadTokens();
  }

  Future<void> _loadTokens() async {
    _accessToken = await _storage.read(key: _tokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      try { _userData = Map<String, dynamic>.from(jsonDecode(userJson) as Map); }
      catch (_) { _userData = null; }
    }
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _userData = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<void> _refreshAccessToken() async {
    final response = await _dio.post('/api/auth/refresh');
    final data = response.data;
    await _saveTokens(data['token'], _refreshToken!);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    int role = 5,
    String? region,
  }) async {
    final response = await _dio.post('/api/auth/register', data: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'region': region,
    });
    final data = response.data;
    final token = data['session']?['access_token'] ?? data['token'];
    await _saveTokens(token, token);
    _userData = Map<String, dynamic>.from(data['user'] as Map);
    await _storage.write(key: _userKey, value: jsonEncode(data['user']));
    return data;
  }

  Future<Map<String, dynamic>> createTeamMember({
    required String email,
    required String password,
    required String fullName,
    required int role,
    String? phone,
    String? regionId,
    String? region,
    String? subRegion,
  }) async {
    final response = await _dio.post('/api/admin/team-members', data: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'region_id': regionId,
      'region': region,
      'sub_region': subRegion,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/api/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data;
    final token = data['session']?['access_token'] ?? data['token'];
    await _saveTokens(token, token);
    _userData = Map<String, dynamic>.from(data['user'] as Map);
    await _storage.write(key: _userKey, value: jsonEncode(data['user']));
    return data;
  }

  Future<void> logout() async {
    await _clearTokens();
  }

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) async {
    final response = await _dio.post('/api/auth/forgot-password', data: {
      'email': email,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> updatePassword({
    required String token,
    required String password,
  }) async {
    await _dio.post('/api/auth/reset-password', data: {
      'token': token,
      'password': password,
    });
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_accessToken == null) return null;
    try {
      final response = await _dio.get('/api/auth/me');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;
  String? get currentUserId {
    final token = _accessToken;
    if (token == null) return null;
    try {
      final payload = token.split('.')[1];
      final normalized = base64Url.normalize(payload);
      final claims = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      return claims['id']?.toString() ?? claims['sub']?.toString();
    } catch (_) {
      return null;
    }
  }
  Map<String, dynamic>? get cachedUser => _userData == null ? null : Map<String, dynamic>.from(_userData!);

  // Generic CRUD methods
  Future<List<dynamic>> getAll(String table, {
    Map<String, dynamic>? filter,
    int limit = 100,
    int offset = 0,
    String orderBy = 'created_at',
    String orderDir = 'DESC',
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'orderBy': orderBy,
      'orderDir': orderDir,
    };
    if (filter != null && filter.isNotEmpty) {
      queryParams['filter'] = jsonEncode(filter);
    }
    final response = await _dio.get('/api/$table', queryParameters: queryParams);
    return response.data;
  }

  // Fetches rows with API-side comparison filters. A scalar keeps the common
  // equality form; operator maps support eq, neq, gt, gte, lt, lte, is, and in.
  Future<List<dynamic>> queryRows(String table, {
    Map<String, dynamic>? filter,
    int limit = 100,
    int offset = 0,
    String orderBy = 'created_at',
    String orderDir = 'DESC',
  }) => getAll(table,
      filter: filter,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderDir: orderDir);

  Future<dynamic> getById(String table, String id) async {
    final response = await _dio.get('/api/$table/$id');
    return response.data;
  }

  Future<dynamic> create(String table, Map<String, dynamic> data) async {
    final response = await _dio.post('/api/$table', data: data);
    return response.data;
  }

  Future<dynamic> update(String table, String id, Map<String, dynamic> data) async {
    final response = await _dio.put('/api/$table/$id', data: data);
    return response.data;
  }

  Future<dynamic> patch(String table, String id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/$table/$id', data: data);
    return response.data;
  }

  Future<void> delete(String table, String id) async {
    await _dio.delete('/api/$table/$id');
  }

  // Raw SQL endpoint
  Future<List<dynamic>> getRaw(String sql) async {
    final response = await _dio.post('/api/raw', data: {'sql': sql});
    return response.data;
  }

  // AI/Report endpoints
  Future<Map<String, dynamic>> generateReport({
    required String reportType,
    Map<String, dynamic>? filters,
    String? prompt,
  }) async {
    final response = await _dio.post('/api/ai/report', data: {
      'report_type': reportType,
      'filters': filters ?? {},
      'prompt': prompt,
    });
    return response.data;
  }

  Future<List<dynamic>> getRole5Performance({
    required String start,
    required String end,
  }) async {
    final response = await _dio.get('/api/reports/role5-performance',
        queryParameters: {'start': start, 'end': end});
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getPotentialSchoolDuplicates() async {
    final response = await _dio.get('/api/reports/potential-duplicates');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSchoolSaleCheckout({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> sale,
  }) async {
    final response = await _dio.post('/api/orders/school-sale-checkout',
        data: {'order': order, 'items': items, 'sale': sale});
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getAdminDashboard() async {
    final response = await _dio.get('/api/admin/dashboard');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> aiChat({
    required List<Map<String, dynamic>> messages,
    String? context,
  }) async {
    final response = await _dio.post('/api/ai/chat', data: {
      'messages': messages,
      'context': context,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getTableData(String table, {
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _dio.get('/api/ai/data/$table', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    return response.data;
  }

  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data;
  }

  // File upload
  Future<String?> uploadFile({
    required String bucket,
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      await _dio.post('/api/upload/$bucket/$fileName', data: bytes, options: Options(
        headers: {'Content-Type': 'application/octet-stream'},
        responseType: ResponseType.json,
      ));
      return '${ApiConfig.baseUrl}/uploads/$bucket/$fileName';
    } catch (e) {
      stderr.writeln('Upload failed: $e');
      return null;
    }
  }
}
