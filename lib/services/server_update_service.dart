import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppVersion {
  final String version;
  final String buildNumber;
  final String apkUrl;

  AppVersion({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      version: json['version'] as String? ?? '',
      buildNumber: (json['build_number'] as int? ?? 0).toString(),
      apkUrl: json['apk_url'] as String? ?? '',
    );
  }
}

class ServerUpdateService {
  static const String _host = 'codingclubskenya.com';
  static const String _versionPath = '/update/version.json';
  static const String _apkPath = '/update/bizx.apk';
  static const String _apkUrl = 'https://$_host$_apkPath';

  static String get apkUrl => _apkUrl;

  Future<AppVersion?> fetchVersionInfo() async {
    final uri = Uri.parse('https://$_host$_versionPath');
    final response = await http.get(uri, headers: {'User-Agent': 'dehus-app'});

    if (response.statusCode != 200) {
      return null;
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AppVersion.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isUpdateAvailable() async {
    final info = await fetchVersionInfo();
    if (info == null) return false;

    final current = await PackageInfo.fromPlatform();
    final currentBuildNumber = current.buildNumber;

    return compareBuildNumbers(info.buildNumber, currentBuildNumber) > 0;
  }

  int compareBuildNumbers(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).whereType<int>().toList();
    final partsB = b.split('.').map(int.tryParse).whereType<int>().toList();

    final maxLen =
        partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < maxLen; i++) {
      final valA = i < partsA.length ? partsA[i] : 0;
      final valB = i < partsB.length ? partsB[i] : 0;
      if (valA > valB) return 1;
      if (valA < valB) return -1;
    }

    return 0;
  }

  Future<String?> downloadApk({
    void Function(int received, int total)? onProgress,
  }) async {
    final dio = Dio();
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/bizx_update.apk';

    try {
      await dio.download(_apkUrl, filePath, onReceiveProgress: onProgress);
      return filePath;
    } catch (_) {
      return null;
    }
  }

  Future<void> installApk(String filePath) async {
    await OpenFile.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
  }
}
