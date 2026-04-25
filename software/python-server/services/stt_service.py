"""STT (Speech-to-Text) service - business logic for audio transcription."""

from typing import Optional
from core.whisper_loader import WhisperLoader


class STTService:
    """Handles audio transcription using Whisper models (Singleton)."""
    
    _instance = None
    
    def __new__(cls):
        """Ensure only one instance exists."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """Initialize STT service with Whisper loader (only once)."""
        if self._initialized:
            return
        self._initialized = True
        self.whisper_loader = WhisperLoader()
        print("[STT_SERVICE] Initialized")
    
    def transcribe_audio(
        self,
        audio_file_path: str,
        model_name: str,
        language: Optional[str] = None,
        device: str = "auto"
    ) -> str:
        """Transcribe an audio file.
        
        Args:
            audio_file_path: Path to audio file
            model_name: Whisper model name (e.g., 'small', 'base')
            language: Optional language code (e.g., 'en')
            device: Device to use ('cpu', 'cuda', or 'auto')
        
        Returns:
            Transcribed text string.
        
        Raises:
            RuntimeError: If transcription fails.
        """
        return self.whisper_loader.transcribe(
            audio_file_path=audio_file_path,
            model_name=model_name,
            language=language,
            device=device
        )
