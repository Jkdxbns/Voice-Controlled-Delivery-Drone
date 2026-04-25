import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';
import 'shared_folder_service.dart';
import 'server/server_config_service.dart';
import 'api/api_headers.dart';
import 'tts_service.dart';

class FileTransferService {
  static final FileTransferService instance = FileTransferService._();
  FileTransferService._();

  Future<void> handleSourceTransfer(Map<String, dynamic> taskData) async {
    try {
      final output = Map<String, dynamic>.from(taskData['output'] ?? {});
      final action = (output['action'] as String? ?? 'copy').toLowerCase();
      final fileQuery = output['file_query'] as String? ?? '';
      final targetMac = output['target_mac'] as String? ?? '';
      final targetName = output['target_name'] as String? ?? 'target device';
      final sourceMac = output['source_mac'] as String? ?? '';
      final sourceName = output['source_name'] as String? ?? 'this device';

      if (fileQuery.trim().isEmpty) {
        await TtsService.instance.speak('Please specify the file name to transfer.');
        return;
      }

      final sharedFolderUri = SharedFolderService.instance.sharedFolderUri;
      if (sharedFolderUri == null) {
        await TtsService.instance.speak('Please select a shared folder in settings first.');
        return;
      }

      final matches = await SharedFolderService.instance.listMatchingFiles(fileQuery);
      final filtered = _filterMatches(matches, fileQuery);

      if (filtered.isEmpty) {
        await TtsService.instance.speak('I could not find $fileQuery in the shared folder.');
        return;
      }

      if (filtered.length > 1) {
        await TtsService.instance.speak('Multiple files match $fileQuery. Please be more specific.');
        return;
      }

      final file = filtered.first;
      AppLogger.info('[FILE_TRANSFER] Found file: ${file.name} (${file.size} bytes)');

      final tempResult = await SharedFolderService.instance.copyToCache(
        uri: file.uri,
        fileName: file.name,
      );

      if (tempResult == null || tempResult['tempPath'] == null) {
        await TtsService.instance.speak('Failed to access the file.');
        return;
      }

      final tempPath = tempResult['tempPath'] as String;
      final checksum = await _computeSha256(tempPath);
      final uploadOk = await _uploadFile(
        tempPath: tempPath,
        originalName: file.name,
        action: action,
        sourceMac: sourceMac,
        targetMac: targetMac,
        checksum: checksum,
      );

      if (!uploadOk.success) {
        await TtsService.instance.speak('Upload failed: ${uploadOk.message}');
        return;
      }

      if (uploadOk.serverChecksum != checksum) {
        await TtsService.instance.speak('Upload integrity check failed.');
        return;
      }

      if (action == 'move') {
        final deleted = await SharedFolderService.instance.deleteFile(file.uri);
        if (!deleted) {
          AppLogger.warning('[FILE_TRANSFER] Move requested but could not delete source file');
        }
      }

      await TtsService.instance.speak('Sent ${file.name} to $targetName');
    } catch (e) {
      AppLogger.error('[FILE_TRANSFER] Source transfer error: $e');
      await TtsService.instance.speak('File transfer failed.');
    }
  }

  Future<void> handleTargetDownload(Map<String, dynamic> taskData) async {
    try {
      final output = Map<String, dynamic>.from(taskData['output'] ?? {});
      final fileId = output['file_id'] as String? ?? '';
      final fileName = output['file_name'] as String? ?? 'file';
      final checksum = output['checksum'] as String? ?? '';
      final sourceName = output['source_name'] as String? ?? 'another device';

      if (fileId.isEmpty) {
        AppLogger.warning('[FILE_TRANSFER] Missing file_id in task');
        return;
      }

      final sharedFolderUri = SharedFolderService.instance.sharedFolderUri;
      if (sharedFolderUri == null) {
        await TtsService.instance.speak('Please select a shared folder in settings first.');
        return;
      }

      final conflict = await SharedFolderService.instance.fileExists(fileName: fileName);
      if (conflict) {
        await TtsService.instance.speak('A file named $fileName already exists in the shared folder. Please rename or remove it and try again.');
        return;
      }

      final tempPath = await _downloadFile(fileId, fileName);
      if (tempPath == null) {
        await TtsService.instance.speak('Download failed.');
        return;
      }

      final localChecksum = await _computeSha256(tempPath);
      if (checksum.isNotEmpty && localChecksum != checksum) {
        await TtsService.instance.speak('Downloaded file failed integrity check.');
        return;
      }

      final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
      final saveResult = await SharedFolderService.instance.saveFileToSharedFolder(
        sourcePath: tempPath,
        fileName: fileName,
        mimeType: mimeType,
      );

      if (saveResult == null || saveResult['status'] != 'saved') {
        await TtsService.instance.speak('Failed to save $fileName to shared folder.');
        return;
      }

      await _safeDeleteTemp(tempPath);
      await TtsService.instance.speak('Received $fileName from $sourceName');
    } catch (e) {
      AppLogger.error('[FILE_TRANSFER] Target download error: $e');
      await TtsService.instance.speak('File download failed.');
    }
  }

  List<SharedFileEntry> _filterMatches(List<SharedFileEntry> entries, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final exact = entries.where((e) => e.name.toLowerCase() == q).toList();
    if (exact.isNotEmpty) return exact;

    final baseExact = entries.where((e) => e.baseNameWithoutExt.toLowerCase() == q).toList();
    if (baseExact.isNotEmpty) return baseExact;

    return entries.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<String> _computeSha256(String filePath) async {
    final file = File(filePath);
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<_UploadResult> _uploadFile({
    required String tempPath,
    required String originalName,
    required String action,
    required String sourceMac,
    required String targetMac,
    required String checksum,
  }) async {
    try {
      final baseUrl = ServerConfigService.instance.baseUrl;
      final url = Uri.parse('$baseUrl/files/upload');
      final headers = await ApiHeaders.getHeaders();

      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      request.fields['action'] = action;
      request.fields['source_mac'] = sourceMac;
      request.fields['target_mac'] = targetMac;
      request.fields['file_name'] = originalName;
      request.fields['checksum'] = checksum;

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        tempPath,
        filename: originalName,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        AppLogger.error('[FILE_TRANSFER] Upload failed: ${response.statusCode}');
        return _UploadResult(false, 'Upload failed', null);
      }

      final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
      if (jsonData['status'] != 'ok') {
        return _UploadResult(false, jsonData['message'] as String? ?? 'Upload failed', null);
      }

      return _UploadResult(true, 'ok', jsonData['checksum'] as String?);
    } catch (e) {
      AppLogger.error('[FILE_TRANSFER] Upload error: $e');
      return _UploadResult(false, 'Upload error', null);
    }
  }

  Future<String?> _downloadFile(String fileId, String fileName) async {
    try {
      final baseUrl = ServerConfigService.instance.baseUrl;
      final url = Uri.parse('$baseUrl/files/download/$fileId');
      final headers = await ApiHeaders.getHeaders();

      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) {
        AppLogger.error('[FILE_TRANSFER] Download failed: ${response.statusCode}');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = fileName.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
      final tempPath = p.join(tempDir.path, 'transfer_${fileId}_$safeName');
      final file = File(tempPath);
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return tempPath;
    } catch (e) {
      AppLogger.error('[FILE_TRANSFER] Download error: $e');
      return null;
    }
  }

  Future<void> _safeDeleteTemp(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class _UploadResult {
  final bool success;
  final String message;
  final String? serverChecksum;

  _UploadResult(this.success, this.message, this.serverChecksum);
}
