import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/app_logger.dart';
import '../../api/models/server_event.dart';
import 'api_headers.dart';

/// Service for AI chat and text generation operations
class ChatApiService {
  final String baseUrl;

  ChatApiService({required this.baseUrl});

  /// Process text input with LM
  /// Returns SSE stream of events
  Stream<ServerEvent> processText({
    required String text,
    required String lmModel,
  }) async* {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.process}');
      
      AppLogger.info('Sending text: ${text.substring(0, text.length.clamp(0, 50))}...');
      AppLogger.info('LM Model: $lmModel');

      final request = http.Request('POST', url);
      
      // Add device tracking headers
      final headers = await ApiHeaders.getJsonHeaders();
      request.headers.addAll(headers);
      
      // Send JSON body for text-only mode
      request.body = jsonEncode({
        'prompt': text,  // Server expects 'prompt' field
        'lm_model': lmModel,  // Support both lm_model and lm_model_name
        // 'stream': true,  // Optional - server defaults to true
      });

      final streamedResponse = await request.send().timeout(
        AppConstants.apiTimeoutXL,
      );

      if (streamedResponse.statusCode != 200) {
        AppLogger.error('Request failed: ${streamedResponse.statusCode}');
        final responseBody = await streamedResponse.stream.bytesToString();
        AppLogger.error('Error response: $responseBody');
        yield ServerEvent(
          type: ServerEventType.error,
          data: 'Request failed: $responseBody',
        );
        return;
      }

      AppLogger.success('Text sent, streaming response...');

      await for (final event in _parseSSEStream(streamedResponse.stream)) {
        yield event;
      }
    } catch (e) {
      AppLogger.error('Text processing error: $e');
      yield ServerEvent(
        type: ServerEventType.error,
        data: 'Processing failed: $e',
      );
    }
  }

  /// Generate content with LM only (streaming)
  /// Legacy endpoint for direct LM generation
  Stream<ServerEvent> generate({
    required String prompt,
    String? model,
  }) async* {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.generate}');
      
      AppLogger.info('Generating: ${prompt.substring(0, prompt.length.clamp(0, 50))}...');

      final request = http.Request('POST', url);
      
      // Add device tracking headers
      final headers = await ApiHeaders.getJsonHeaders();
      request.headers.addAll(headers);
      
      request.body = jsonEncode({
        'prompt': prompt,
        if (model != null) 'model': model,
      });

      final streamedResponse = await request.send().timeout(
        AppConstants.apiTimeoutXL,
      );

      if (streamedResponse.statusCode != 200) {
        AppLogger.error('Generation failed: ${streamedResponse.statusCode}');
        yield ServerEvent(
          type: ServerEventType.error,
          data: 'Generation failed with status ${streamedResponse.statusCode}',
        );
        return;
      }

      await for (final event in _parseSSEStream(streamedResponse.stream)) {
        yield event;
      }
    } catch (e) {
      AppLogger.error('Generation error: $e');
      yield ServerEvent(
        type: ServerEventType.error,
        data: 'Generation failed: $e',
      );
    }
  }

  /// Parse Server-Sent Events stream
  Stream<ServerEvent> _parseSSEStream(Stream<List<int>> byteStream) async* {
    String buffer = '';
    String? currentEventType;

    await for (final chunk in byteStream.transform(utf8.decoder)) {
      buffer += chunk;

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
          AppLogger.debug('SSE event type: $currentEventType');
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

          yield ServerEvent(type: type, data: data);
          
          if (type == ServerEventType.done || type == ServerEventType.error) {
            AppLogger.info('Stream ended: $type');
            return;
          }
        }
      }
    }
  }
}
