"""Whisper model loading and caching for Speech-to-Text."""

from pathlib import Path
from typing import Dict, Optional

try:
    from faster_whisper import WhisperModel
    _whisper_import_error = None
except ImportError as e:
    WhisperModel = None
    _whisper_import_error = e

try:
    import torch
    _torch_import_error = None
except ImportError as e:
    torch = None
    _torch_import_error = e

from config import WHISPER_CACHE


class WhisperLoader:
    """Manages Whisper model loading and in-memory caching (Singleton)."""
    
    _instance = None
    
    def __new__(cls):
        """Ensure only one instance exists."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """Initialize the Whisper loader with empty cache (only once)."""
        if self._initialized:
            return
        self._initialized = True
        self._cache: Dict[str, dict] = {}
        print(f"[WHISPER] Initialized loader with cache: {WHISPER_CACHE}")
    
    def detect_device(self) -> str:
        """Detect if CUDA is available.
        
        Returns:
            'cuda' if CUDA is available, 'cpu' otherwise.
        """
        if torch is not None:
            try:
                return "cuda" if torch.cuda.is_available() else "cpu"
            except Exception:
                return "cpu"
        return "cpu"
    
    def clear_cached_model(self, model_name: str) -> None:
        """Remove a model from cache to free memory.
        
        Args:
            model_name: Name of the model to remove from cache.
        """
        if model_name in self._cache:
            print(f"[WHISPER] Clearing cached model: {model_name}")
            del self._cache[model_name]
    
    def get_model(self, model_name: str, device: str = "auto"):
        """Load or retrieve cached Whisper model.
        
        Implements caching strategy:
        - If model is already cached and device matches, reuse it
        - If different model requested, clear old cache and load new model
        - Device is auto-detected on each call for dynamic CUDA availability
        
        Args:
            model_name: Display name from faster-whisper (e.g., 'small', 'base', 'large-v3')
            device: 'cpu', 'cuda', or 'auto' (auto-detect GPU)
        
        Returns:
            Configured WhisperModel instance.
        
        Raises:
            RuntimeError: If faster-whisper is not installed or model loading fails.
        """
        if WhisperModel is None:
            raise RuntimeError(
                f"faster-whisper is not installed: {_whisper_import_error!r}. "
                "Install with: pip install faster-whisper"
            )
        
        # Auto-detect device if requested
        if device == "auto":
            device = self.detect_device()
        
        # Check if model is already cached in memory
        if model_name in self._cache:
            cached_entry = self._cache[model_name]
            cached_device = cached_entry.get("device")
            
            # If device changed, reload model
            if cached_device == device:
                print(f"[WHISPER] Reusing cached model: {model_name} on {device}")
                return cached_entry["model"]
            else:
                print(f"[WHISPER] Device changed ({cached_device} → {device}), reloading...")
                self.clear_cached_model(model_name)
        
        # Clear any other cached models (keep only one model in memory)
        for cached_name in list(self._cache.keys()):
            if cached_name != model_name:
                self.clear_cached_model(cached_name)
        
        try:
            # Load model (faster-whisper handles local cache automatically)
            print(f"[WHISPER] Loading model: {model_name} on {device}")
            model = WhisperModel(
                model_name,
                device=device,
                compute_type="int8",
                download_root=str(WHISPER_CACHE),
            )
            
            # Cache the loaded model in memory
            self._cache[model_name] = {
                "model": model,
                "device": device
            }
            
            print(f"[WHISPER] Model loaded: {model_name}")
            return model
            
        except Exception as e:
            raise RuntimeError(f"Failed to load Whisper model {model_name}: {e}")
    
    def transcribe(
        self,
        audio_file_path: str,
        model_name: str,
        language: Optional[str] = None,
        device: str = "auto"
    ) -> str:
        """Transcribe an audio file using a Whisper model.
        
        Args:
            audio_file_path: Path to the audio file (.wav, .mp3, etc.)
            model_name: Display name from faster-whisper (e.g., 'small', 'base')
            language: Optional language code (e.g., 'en'). Auto-detect if None.
            device: 'cpu', 'cuda', or 'auto' (recommended: 'auto')
        
        Returns:
            Transcribed text as a string.
        
        Raises:
            RuntimeError: If transcription fails.
        """
        model = self.get_model(model_name, device=device)
        
        try:
            # Transcribe with faster-whisper
            segments, info = model.transcribe(
                audio_file_path,
                language=language,
                beam_size=5,
                vad_filter=True,
            )
            
            # Convert generator to list
            segment_list = list(segments)
            
            # Check if no segments detected (empty audio or silence)
            if not segment_list:
                return ""
            
            # Concatenate all segments
            transcription = " ".join([segment.text for segment in segment_list])
            return transcription.strip()
            
        except Exception as e:
            # If transcription fails (e.g., empty audio), return empty string
            print(f"[WHISPER] Transcription failed: {e}")
            return ""
