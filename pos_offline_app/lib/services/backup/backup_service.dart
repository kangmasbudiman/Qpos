import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_constants.dart';

class BackupService extends GetxService {
  final _storage = const FlutterSecureStorage();

  /// Download backup database dari server dan simpan ke cache directory.
  /// Cache directory bisa diakses share_plus via FileProvider (Android safe).
  /// Return: path file yang tersimpan, atau throw Exception jika gagal.
  Future<String> downloadBackup() async {
    final token = await _storage.read(key: AppConstants.authTokenKey);
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('${AppConstants.baseUrl}/backup/download');

    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/gzip',
    }).timeout(const Duration(minutes: 5));

    if (response.statusCode != 200) {
      String msg = 'Server error (${response.statusCode})';
      try {
        final body = response.body;
        debugPrint('[BackupService] Error body: $body');
        if (body.contains('"message"')) {
          final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(body);
          if (match != null) msg = match.group(1)!;
        }
      } catch (_) {}
      throw Exception(msg);
    }

    debugPrint('[BackupService] Response size: ${response.bodyBytes.length} bytes');

    if (response.bodyBytes.isEmpty) {
      throw Exception('Backup file kosong');
    }

    final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final filename = 'backup_$dateStr.sql.gz';

    // Simpan ke cache — accessible oleh share_plus FileProvider
    final cacheDir = await getTemporaryDirectory();
    final cachePath = '${cacheDir.path}/$filename';
    await File(cachePath).writeAsBytes(response.bodyBytes);
    debugPrint('[BackupService] Saved to cache: $cachePath');

    // Juga simpan ke Downloads agar terlihat di file manager & bisa dipilih saat restore
    try {
      final downloadsPath = await _getDownloadsPath();
      if (downloadsPath != null) {
        final dlFile = File('$downloadsPath/$filename');
        await dlFile.writeAsBytes(response.bodyBytes);
        debugPrint('[BackupService] Saved to Downloads: ${dlFile.path}');
      }
    } catch (e) {
      debugPrint('[BackupService] Could not save to Downloads: $e');
      // Tidak throw — file cache tetap tersedia untuk share
    }

    return cachePath;
  }

  /// Dapatkan path folder Downloads yang bisa diakses file manager.
  Future<String?> _getDownloadsPath() async {
    if (!Platform.isAndroid) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }

    // Android ≤ 9 perlu permission WRITE_EXTERNAL_STORAGE
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // Path Downloads standar Android
    const downloadsDir = '/storage/emulated/0/Download';
    final dir = Directory(downloadsDir);
    if (await dir.exists()) return downloadsDir;

    // Fallback ke external storage app dir
    final extDirs = await getExternalStorageDirectories();
    if (extDirs != null && extDirs.isNotEmpty) {
      return extDirs.first.path;
    }
    return null;
  }

  /// Upload file .sql.gz ke server untuk di-restore ke database.
  /// Throws Exception jika gagal.
  Future<void> restoreBackup(String filePath) async {
    final token = await _storage.read(key: AppConstants.authTokenKey);
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('${AppConstants.baseUrl}/backup/restore');
    final filename = filePath.split('/').last;

    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: filename,
      contentType: MediaType('application', 'gzip'),
    ));

    debugPrint('[BackupService] Uploading restore file: $filename');

    final streamedResponse = await request.send().timeout(const Duration(minutes: 10));
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('[BackupService] Restore response: ${response.statusCode} ${response.body}');

    if (response.statusCode != 200) {
      String msg = 'Server error (${response.statusCode})';
      try {
        final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(response.body);
        if (match != null) msg = match.group(1)!;
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
