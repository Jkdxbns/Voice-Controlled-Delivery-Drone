import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../utils/app_logger.dart';
import '../../api/models/server_event.dart';
import '../../models/assistant_response.dart';
import 'api_headers.dart';

/// Service for assistant API operations (two-pass LLM pipeline)
class AssistantApiService {
  final String baseUrl;

  AssistantApiService({required this.baseUrl});

  /// Handle assistant request with two-pass pipeline
  /// Returns either streaming events (text-generation) or JSON response (bt-control)
  Future<AssistantApiResult> handleRequest({
    required String userQuery,
    String? lmModel,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/lm/query');
      
      AppLogger.info('Assistant request: ${userQuery.substring(0, userQuery.length.clamp(0, 50))}...');

      final headers = await ApiHeaders.getJsonHeaders();
      
      final body = jsonEncode({
        'user_query': userQuery,
        'source_device_mac': headers['X-Device-MAC'],
        if (lmModel != null) 'lm_model': lmModel,
      });

      final request = http.Request('POST', url);
      request.headers.addAll(headers);
      request.body = body;

      final streamedResponse = await request.send().timeout(
        AppConstants.apiTimeoutXL,
      );

      if (streamedResponse.statusCode != 200) {
        AppLogger.error('Assistant request failed: ${streamedResponse.statusCode}');
        final responseBody = await streamedResponse.stream.bytesToString();
        AppLogger.error('Error response: $responseBody');
        
        return AssistantApiResult.error(
          'Request failed: ${streamedResponse.statusCode}',
        );
      }

      // Check content type to determine if streaming or JSON
      final contentType = streamedResponse.headers['content-type'] ?? '';
      
      if (contentType.contains('text/event-stream')) {
        // Streaming response (text-generation)
        AppLogger.success('Streaming response detected');
        return AssistantApiResult.streaming(
          _parseSSEStream(streamedResponse.stream),
        );
      } else {
        // JSON response (bt-control or routed)
        AppLogger.success('JSON response detected');
        final responseBody = await streamedResponse.stream.bytesToString();
        final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
        
        if (jsonData['status'] == 'error') {
          final error = jsonData['error'] as Map<String, dynamic>;
          return AssistantApiResult.error(error['message'] as String);
        }
        
        // Handle "routed" status - command was sent to another device via WebSocket
        if (jsonData['status'] == 'routed') {
          final message = jsonData['message'] as String? ?? 'Command routed';
          final targetDevice = jsonData['target_device'] as String? ?? 'device';
          AppLogger.success('Command routed to another device: $message');
          return AssistantApiResult.routed(message, targetDevice);
        }
        
        final result = jsonData['result'] as Map<String, dynamic>;
        final assistantResponse = AssistantResponse.fromJson(result);
        
        return AssistantApiResult.json(assistantResponse);
      }
    } catch (e) {
      AppLogger.error('Assistant request error: $e');
      return AssistantApiResult.error('Request failed: $e');
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

          // Parse chunk from JSON
          try {
            final jsonData = jsonDecode(data) as Map<String, dynamic>;
            
            // For status/done events, keep the full JSON for parsing
            if (type == ServerEventType.status || type == ServerEventType.done) {
              AppLogger.debug('SSE parsed (full JSON): $type - $data');
              yield ServerEvent(type: type, data: data);
            }
            // For data events, extract the chunk text
            else if (jsonData.containsKey('chunk')) {
              final chunkText = jsonData['chunk'] as String;
              AppLogger.debug('SSE chunk: ${chunkText.substring(0, chunkText.length.clamp(0, 50))}...');
              yield ServerEvent(type: type, data: chunkText); // Extract clean text
            }
            // For errors, extract error message
            else if (jsonData.containsKey('error')) {
              AppLogger.error('SSE error: ${jsonData['error']}');
              yield ServerEvent(type: ServerEventType.error, data: jsonData['error'] as String);
            }
            // Unknown format, yield as-is
            else {
              AppLogger.warning('SSE unknown format: $data');
              yield ServerEvent(type: type, data: data);
            }
          } catch (e) {
            // Not JSON, use as-is
            yield ServerEvent(type: type, data: data);
          }
          
          if (type == ServerEventType.done || type == ServerEventType.error) {
            AppLogger.info('Stream ended: $type');
            return;
          }
        }
      }
    }
  }
}

/// Result type for assistant API calls
class AssistantApiResult {
  final AssistantApiResultType type;
  final Stream<ServerEvent>? streamingEvents;
  final AssistantResponse? jsonResponse;
  final String? error;
  final String? routedMessage;
  final String? targetDevice;

  const AssistantApiResult._({
    required this.type,
    this.streamingEvents,
    this.jsonResponse,
    this.error,
    this.routedMessage,
    this.targetDevice,
  });

  factory AssistantApiResult.streaming(Stream<ServerEvent> events) {
    return AssistantApiResult._(
      type: AssistantApiResultType.streaming,
      streamingEvents: events,
    );
  }

  factory AssistantApiResult.json(AssistantResponse response) {
    return AssistantApiResult._(
      type: AssistantApiResultType.json,
      jsonResponse: response,
    );
  }

  factory AssistantApiResult.error(String message) {
    return AssistantApiResult._(
      type: AssistantApiResultType.error,
      error: message,
    );
  }

  factory AssistantApiResult.routed(String message, String targetDevice) {
    return AssistantApiResult._(
      type: AssistantApiResultType.routed,
      routedMessage: message,
      targetDevice: targetDevice,
    );
  }

  bool get isStreaming => type == AssistantApiResultType.streaming;
  bool get isJson => type == AssistantApiResultType.json;
  bool get isError => type == AssistantApiResultType.error;
  bool get isRouted => type == AssistantApiResultType.routed;
}

enum AssistantApiResultType {
  streaming,
  json,
  error,
  routed,
}
