/// API endpoint paths for server communication
class ApiEndpoints {
  ApiEndpoints._();

  // Health & Status
  static const String health = '/health';
  static const String status = '/status';

  // Model Management
  static const String catalog = '/catalog';

  // Device Management
  static const String registerDevice = '/device/register';
  static const String deviceList = '/device/list';

  // AI Processing (STT + LM combined)
  static const String process = '/ai/process';
  
  // Language Model (LM)
  static const String generate = '/lm/generate';
  static const String query = '/lm/query';
  
  // Speech-to-Text (STT)
  static const String transcribe = '/stt/transcribe';

  // Testing
  static const String echo = '/echo';

  // Legacy/Compatibility (if needed)
  static const String chat = '/chat';
  static const String streamChat = '/stream_chat';
  static const String transcribeStream = '/transcribe_stream';
  static const String uploadAudio = '/upload_audio';
  static const String processAudio = '/process_audio';

  // Helper Methods
  static String getFullUrl(String baseUrl, String endpoint) {
    return '$baseUrl$endpoint';
  }
}
