import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/app_logger.dart';
import '../../api/models/server_event.dart';
import 'api_headers.dart';

/// Service for audio transcription operations
class TranscriptionApiService {
  final String baseUrl;

  TranscriptionApiService({required this.baseUrl});

  /// Transcribe audio only (no LM generation)
  /// Returns just the transcribed text
  Future<String> transcribeAudio({
    required String audioFilePath,
    required String sttModel,
  }) async {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.transcribe}');
      
      AppLogger.info('Uploading audio for transcription: $audioFilePath');
      AppLogger.info('STT Model: $sttModel');

      final request = http.MultipartRequest('POST', url);
      
      // Add device tracking headers
      final headers = await ApiHeaders.getHeaders();
      request.headers.addAll(headers);
      
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFilePath),
      );
      request.fields['stt_model_name'] = sttModel;

      final streamedResponse = await request.send().timeout(
        AppConstants.apiTimeoutXL,
      );

      if (streamedResponse.statusCode != 200) {
        AppLogger.error('Transcription failed: ${streamedResponse.statusCode}');
        final responseBody = await streamedResponse.stream.bytesToString();
        AppLogger.error('Error response: $responseBody');
        throw Exception('Transcription failed: $responseBody');
      }

      final responseBody = await streamedResponse.stream.bytesToString();
      final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
      
      if (jsonData['status'] != 'success') {
        throw Exception(jsonData['error'] ?? 'Transcription failed');
      }
      
      final transcription = jsonData['transcription'] as String;
      AppLogger.success('Transcription received: ${transcription.substring(0, transcription.length.clamp(0, 50))}...');
      
      return transcription;
    } catch (e) {
      AppLogger.error('Transcription error: $e');
      rethrow;
    }
  }

  /// Process audio file with STT and LM
  /// Returns stream of events (SSE format from server)
  Stream<ServerEvent> processAudio({
    required String audioFilePath,
    required String sttModel,
    required String lmModel,
  }) async* {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.process}');
      
      AppLogger.info('Uploading audio: $audioFilePath');
      AppLogger.info('STT Model: $sttModel, LM Model: $lmModel');

      final request = http.MultipartRequest('POST', url);
      
      // Add device tracking headers
      final headers = await ApiHeaders.getHeaders();
      request.headers.addAll(headers);
      
      AppLogger.info('API Headers: ${headers.keys.join(", ")}');
      
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFilePath),
      );
      // Use correct field names that match server expectations
      request.fields['stt_model_name'] = sttModel;
      request.fields['lm_model_name'] = lmModel;
      // Explicitly enable streaming (server defaults to FALSE!)
      request.fields['stream'] = 'true';

      final streamedResponse = await request.send().timeout(
        AppConstants.apiTimeoutXXL,
      );

      if (streamedResponse.statusCode != 200) {
        AppLogger.error('Upload failed: ${streamedResponse.statusCode}');
        final responseBody = await streamedResponse.stream.bytesToString();
        AppLogger.error('Error response: $responseBody');
        yield ServerEvent(
          type: ServerEventType.error,
          data: 'Upload failed: $responseBody',
        );
        return;
      }

      AppLogger.success('Audio uploaded, streaming response...');

      // Parse SSE stream from server
      await for (final event in _parseSSEStream(streamedResponse.stream)) {
        yield event;
      }
    } catch (e) {
      AppLogger.error('Audio processing error: $e');
      yield ServerEvent(
        type: ServerEventType.error,
        data: 'Processing failed: $e',
      );
    }
  }

  /// Parse Server-Sent Events stream
  /// Matches the v4 working implementation
  Stream<ServerEvent> _parseSSEStream(Stream<List<int>> byteStream) async* {
    String buffer = '';
    String? currentEventType;

    AppLogger.info('📡 Starting SSE stream parsing...');

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer += chunk;
      AppLogger.debug('📦 SSE chunk received: ${chunk.length} bytes');
      // Log first 200 chars of raw data to see what server sent
      final preview = chunk.substring(0, chunk.length > 200 ? 200 : chunk.length);
      AppLogger.debug('📄 SSE raw data: $preview');

      while (buffer.contains('\n')) {
        final newlineIndex = buffer.indexOf('\n');
        final line = buffer.substring(0, newlineIndex).trim();
        buffer = buffer.substring(newlineIndex + 1);

        if (line.isEmpty) {
          currentEventType = null;
          continue;
        }

        if (line.startsWith('event:')) {
          currentEventType = line.substring(6).trim();
          AppLogger.info('🎯 SSE event type: $currentEventType');
        } else if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          
          ServerEventType type;
          if (currentEventType == 'status') {
            type = ServerEventType.status;
          } else if (currentEventType == 'done') {
            type = ServerEventType.done;
          } else if (currentEventType == 'error') {
            type = ServerEventType.error;
          } else {
            type = ServerEventType.data;
          }

          final dataPreview = data.length > 100 ? "${data.substring(0, 100)}..." : data;
          AppLogger.info('✅ SSE parsed: $type - $dataPreview');
          yield ServerEvent(type: type, data: data);
          
          if (type == ServerEventType.done || type == ServerEventType.error) {
            AppLogger.success('🏁 Stream ended: $type');
            return;
          }
        }
      }
    }
    
    AppLogger.warning('Stream closed unexpectedly');
  }
}
