import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../utils/app_logger.dart';
import 'preferences_service.dart';

class SharedFileEntry {
  final String uri;
  final String name;
  final String? mimeType;
  final int size;

  const SharedFileEntry({
    required this.uri,
    required this.name,
    required this.mimeType,
    required this.size,
  });

  String get baseName => p.basename(name);
  String get baseNameWithoutExt => p.basenameWithoutExtension(name);
}

class SharedFolderService {
  static final SharedFolderService instance = SharedFolderService._();
  SharedFolderService._();

  static const MethodChannel _channel = MethodChannel('coffin/shared_storage');

  String? get sharedFolderUri {
    final uri = PreferencesService.instance.sharedFolderUri;
    if (uri == null || uri.isEmpty) {
      return null;
    }
    return uri;
  }

  Future<String?> pickSharedFolder() async {
    try {
      final uri = await _channel.invokeMethod<String>('pickSharedFolder');
      if (uri == null || uri.isEmpty) {
        return null;
      }
      await PreferencesService.instance.setSharedFolderUri(uri);
      return uri;
    } catch (e) {
      AppLogger.error('[SHARED_FOLDER] Failed to pick folder: $e');
      return null;
    }
  }

  Future<void> clearSharedFolder() async {
    await PreferencesService.instance.setSharedFolderUri('');
  }

  Future<List<SharedFileEntry>> listMatchingFiles(String query) async {
    final treeUri = sharedFolderUri;
    if (treeUri == null) {
      return [];
    }

    try {
      final results = await _channel.invokeMethod<List<dynamic>>(
        'listFiles',
        {
          'treeUri': treeUri,
          'query': query,
        },
      );

      if (results == null) return [];

      return results
          .whereType<Map>()
          .map((raw) {
            final map = Map<String, dynamic>.from(raw as Map);
            return SharedFileEntry(
              uri: map['uri'] as String,
              name: map['name'] as String? ?? 'unknown',
              mimeType: map['mimeType'] as String?,
              size: (map['size'] as num?)?.toInt() ?? 0,
            );
          })
          .toList();
    } catch (e) {
      AppLogger.error('[SHARED_FOLDER] Failed to list files: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> copyToCache({
    required String uri,
    required String fileName,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'copyToCache',
        {
          'uri': uri,
          'fileName': fileName,
        },
      );

      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      AppLogger.error('[SHARED_FOLDER] Failed to copy to cache: $e');
      return null;
    }
  }

  Future<bool> deleteFile(String uri) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteFile', {
        'uri': uri,
      });
      return result ?? false;
    } catch (e) {
      AppLogger.error('[SHARED_FOLDER] Failed to delete file: $e');
      return false;
    }
  }

  Future<bool> fileExists({
    required String fileName,
  }) async {
    final treeUri = sharedFolderUri;
    if (treeUri == null) return false;

    try {
      final result = await _channel.invokeMethod<bool>('fileExists', {
        'treeUri': treeUri,
        'fileName': fileName,
      });
      return result ?? false;
    } catch (e) {
      AppLogger.error('[SHARED_FOLDER] Failed to check file existence: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> saveFileToSharedFolder({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    final treeUri = sharedFolderUri;
    if (treeUri == null) return null;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'saveFileToSharedFolder',
        {
          'treeUri': treeUri,
          'sourcePath': sourcePath,
          'fileName': fileName,
          'mimeType': mimeType,
        },
      );

      if (result == null) return null;
      return Map<String, dynamic>.from(result);
    } catch (e) {
      AppLogger.error('[SHARED_FOLDER] Failed to save file: $e');
      return null;
    }
  }
}
