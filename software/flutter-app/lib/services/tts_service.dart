import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/app_logger.dart';
import 'preferences_service.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;
  
  TtsService._internal();
  
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  
  // ValueNotifier for reactive UI updates
  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  
  bool get isSpeaking => isSpeakingNotifier.value;
  
  // Streaming playback flags and buffer
  bool _isStreamMode = false;
  final List<String> _chunkBuffer = [];
  bool _isProcessingBuffer = false;
  bool _shouldStopWhenBufferEmpty = false;  // Flag to stop playback when buffer empties
  
  // Cache RegExp objects to avoid recreation on every call
  static final _regexBold = RegExp(r'\*\*([^\*]+)\*\*');
  static final _regexItalic = RegExp(r'\*([^\*]+)\*');
  static final _regexCodeBlock = RegExp(r'```[^`]*```');
  static final _regexInlineCode = RegExp(r'`([^`]+)`');
  static final _regexHeaders = RegExp(r'^#{1,6}\s+', multiLine: true);
  static final _regexLinks = RegExp(r'\[([^\]]+)\]\([^\)]+\)');
  static final _regexSpecialChars = RegExp(r'[_~\[\]\{\}]');
  static final _regexMultiSpaces = RegExp(r'\s+');
  
  /// Clean text for TTS by removing markdown and special characters (optimized with cached RegExp)
  String _cleanTextForTTS(String text) {
    return text
        .replaceAll(_regexBold, r'$1') // **bold**
        .replaceAll(_regexItalic, r'$1') // *italic*
        .replaceAll(_regexCodeBlock, '') // code blocks
        .replaceAll(_regexInlineCode, r'$1') // inline code
        .replaceAll(_regexHeaders, '') // headers
        .replaceAll(_regexLinks, r'$1') // links
        .replaceAll(_regexSpecialChars, '') // special punctuation
        .replaceAll(_regexMultiSpaces, ' ') // multiple spaces
        .trim();
  }
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _flutterTts = FlutterTts();
      
      // Set up handlers
      _flutterTts!.setStartHandler(() {
        isSpeakingNotifier.value = true;
        AppLogger.debug('TTS: Started speaking');
      });
      
      _flutterTts!.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
        AppLogger.debug('TTS: Completed speaking');
        
        // Check if buffer is empty and we should stop
        if (_chunkBuffer.isEmpty && _shouldStopWhenBufferEmpty) {
          AppLogger.info('TTS: Buffer empty, stopping playback');
          _isStreamMode = false;
          _shouldStopWhenBufferEmpty = false;
          _isProcessingBuffer = false;
          return;
        }
        
        // Process next chunk from buffer if available
        if (_chunkBuffer.isNotEmpty) {
          _processNextChunk();
        } else {
          _isProcessingBuffer = false;
        }
      });
      
      _flutterTts!.setErrorHandler((msg) {
        isSpeakingNotifier.value = false;
        AppLogger.error('TTS Error: $msg');
        
        // Check if buffer is empty and we should stop
        if (_chunkBuffer.isEmpty && _shouldStopWhenBufferEmpty) {
          AppLogger.info('TTS: Buffer empty after error, stopping playback');
          _isStreamMode = false;
          _shouldStopWhenBufferEmpty = false;
          _isProcessingBuffer = false;
          return;
        }
        
        // Try to recover by processing next chunk
        if (_chunkBuffer.isNotEmpty) {
          _processNextChunk();
        } else {
          _isProcessingBuffer = false;
        }
      });
      
      _flutterTts!.setCancelHandler(() {
        isSpeakingNotifier.value = false;
        AppLogger.debug('TTS: Cancelled');
        _isProcessingBuffer = false;
      });
      
      // Load settings from preferences
      await _loadSettings();
      
      _isInitialized = true;
      AppLogger.success('TTS Service initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize TTS: $e');
    }
  }
  
  Future<void> _loadSettings() async {
    if (_flutterTts == null) return;
    
    final prefs = PreferencesService.instance;
    final speed = prefs.ttsSpeed;
    final pitch = prefs.ttsPitch;
    final volume = prefs.ttsVolume;
    
    AppLogger.info('TTS: Applying settings - speed=$speed, pitch=$pitch, volume=$volume');
    
    // Batch all settings together (reduced await overhead)
    await Future.wait([
      _flutterTts!.setLanguage("en-US"),
      _flutterTts!.setSpeechRate(speed),
      _flutterTts!.setPitch(pitch),
      _flutterTts!.setVolume(volume),
    ]);
    
    AppLogger.success('TTS settings applied successfully');
  }
  
  Future<void> speak(String text) async {
    // Check if TTS is enabled BEFORE initialization (early return optimization)
    if (!PreferencesService.instance.ttsEnabled) {
      AppLogger.info('TTS is disabled');
      return;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_flutterTts == null) {
      AppLogger.error('TTS not initialized');
      return;
    }
    
    try {
      // Stop any ongoing speech
      if (isSpeaking) {
        await stop();
      }
      
      // Clean text before speaking
      final cleanedText = _cleanTextForTTS(text);
      
      if (cleanedText.isEmpty) {
        AppLogger.info('TTS: No text to speak after cleaning');
        return;
      }
      
      AppLogger.info('TTS: Speaking text (${cleanedText.length} characters)');
      
      // Speak the cleaned text
      await _flutterTts!.speak(cleanedText);
    } catch (e) {
      AppLogger.error('TTS speak error: $e');
    }
  }
  
  /// Initialize streaming mode - sets flag to buffer chunks
  void startStreamMode() {
    _isStreamMode = true;
    _chunkBuffer.clear();
    _isProcessingBuffer = false;
    _shouldStopWhenBufferEmpty = false;
    AppLogger.info('TTS: Stream mode enabled');
  }
  
  /// End streaming mode - sets flag to stop when buffer empties
  void endStreamMode() {
    _shouldStopWhenBufferEmpty = true;
    AppLogger.info('TTS: Stream ended, will stop when buffer empties (${_chunkBuffer.length} chunks remaining)');
  }
  
  /// Force stop and clear everything
  void stopStreaming() {
    _isStreamMode = false;
    _shouldStopWhenBufferEmpty = false;
    _chunkBuffer.clear();
    _isProcessingBuffer = false;
    AppLogger.info('TTS: Streaming stopped and buffer cleared');
  }
  
  /// Add a text chunk to the buffer for streamed playback
  Future<void> speakChunk(String textChunk) async {
    // Check if TTS is enabled
    if (!PreferencesService.instance.ttsEnabled) {
      return;
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_flutterTts == null) {
      AppLogger.error('TTS not initialized');
      return;
    }
    
    // Clean the chunk
    final cleanedText = _cleanTextForTTS(textChunk);
    
    if (cleanedText.isEmpty) {
      return;
    }
    
    // Add to buffer
    _chunkBuffer.add(cleanedText);
    AppLogger.debug('TTS: Chunk buffered (${cleanedText.length} chars, buffer size: ${_chunkBuffer.length})');
    
    // If not currently playing, start processing buffer
    if (!_isProcessingBuffer && !isSpeaking) {
      _processNextChunk();
    }
  }
  
  /// Process the next chunk from the buffer
  Future<void> _processNextChunk() async {
    if (_chunkBuffer.isEmpty || isSpeaking || _flutterTts == null) {
      _isProcessingBuffer = false;
      return;
    }
    
    _isProcessingBuffer = true;
    
    try {
      // Get the next chunk from buffer (FIFO)
      final chunk = _chunkBuffer.removeAt(0);
      
      AppLogger.info('TTS: Playing chunk (${chunk.length} chars, ${_chunkBuffer.length} remaining in buffer)');
      
      // Speak the chunk
      await _flutterTts!.speak(chunk);
    } catch (e) {
      AppLogger.error('TTS chunk playback error: $e');
      _isProcessingBuffer = false;
      
      // Try to continue with next chunk
      if (_chunkBuffer.isNotEmpty) {
        _processNextChunk();
      }
    }
  }
  
  Future<void> stop() async {
    if (_flutterTts == null) return;
    
    try {
      await _flutterTts!.stop();
      isSpeakingNotifier.value = false;
      _isProcessingBuffer = false;
      // Clear buffer on stop
      if (_isStreamMode) {
        _chunkBuffer.clear();
        AppLogger.debug('TTS: Buffer cleared on stop');
      }
    } catch (e) {
      AppLogger.error('TTS stop error: $e');
    }
  }
  
  Future<void> pause() async {
    if (_flutterTts == null) return;
    
    try {
      await _flutterTts!.pause();
    } catch (e) {
      AppLogger.error('TTS pause error: $e');
    }
  }
  
  // Generic method to update TTS parameter (DRY principle)
  Future<void> _updateParameter(
    String paramName,
    double value,
    Future<void> Function(FlutterTts, double) setter,
    Future<void> Function(double) preferenceSetter,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_flutterTts == null) {
      AppLogger.error('TTS: Cannot update $paramName - initialization failed');
      return;
    }
    
    AppLogger.info('TTS: Setting $paramName to $value');
    await Future.wait([
      setter(_flutterTts!, value),
      preferenceSetter(value),
    ]);
    AppLogger.success('TTS: $paramName updated and saved to $value');
  }
  
  Future<void> updateSpeed(double speed) => _updateParameter(
    'speed',
    speed,
    (tts, value) => tts.setSpeechRate(value),
    PreferencesService.instance.setTtsSpeed,
  );
  
  Future<void> updatePitch(double pitch) => _updateParameter(
    'pitch',
    pitch,
    (tts, value) => tts.setPitch(value),
    PreferencesService.instance.setTtsPitch,
  );
  
  Future<void> updateVolume(double volume) => _updateParameter(
    'volume',
    volume,
    (tts, value) => tts.setVolume(value),
    PreferencesService.instance.setTtsVolume,
  );
  
  void dispose() {
    _flutterTts?.stop();
    _isInitialized = false;
    _isStreamMode = false;
    _shouldStopWhenBufferEmpty = false;
    _chunkBuffer.clear();
    _isProcessingBuffer = false;
  }
}
