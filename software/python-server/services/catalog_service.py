"""Model catalog service - manages available STT and LM models."""

from typing import Dict, Tuple
from core.utils import load_json, save_json
from core.gemini_loader import GeminiLoader
from config import MODEL_CATALOG_PATH


def _get_whisper_models() -> dict:
    """Get available Whisper models from faster-whisper library.
    
    Returns:
        Dictionary mapping model keys to repository IDs.
    """
    try:
        from faster_whisper.utils import _MODELS
        return dict(_MODELS)
    except (ImportError, AttributeError):
        print("[CATALOG] Warning: faster-whisper._MODELS not available, using fallback")
        return {
            "tiny": "Systran/faster-whisper-tiny",
            "tiny.en": "Systran/faster-whisper-tiny.en",
            "base": "Systran/faster-whisper-base",
            "base.en": "Systran/faster-whisper-base.en",
            "small": "Systran/faster-whisper-small",
            "small.en": "Systran/faster-whisper-small.en",
            "medium": "Systran/faster-whisper-medium",
            "medium.en": "Systran/faster-whisper-medium.en",
            "large-v1": "Systran/faster-whisper-large-v1",
            "large-v2": "Systran/faster-whisper-large-v2",
            "large-v3": "Systran/faster-whisper-large-v3",
        }


def _get_gemini_models_fallback() -> dict:
    """Fallback Gemini models if API is not accessible.
    
    Returns:
        Dictionary of default Gemini models.
    """
    return {
        "gemini-2.5-flash": "models/gemini-2.5-flash",
        "gemini-2.5-pro": "models/gemini-2.5-pro",
        "gemini-flash-latest": "models/gemini-flash-latest",
        "gemini-2.5-flash-lite": "models/gemini-2.5-flash-lite",
    }


class CatalogService:
    """Manages model catalog for STT and LM models (Singleton)."""
    
    _instance = None
    
    def __new__(cls):
        """Ensure only one instance exists."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """Initialize catalog service (only once)."""
        if self._initialized:
            return
        self._initialized = True
        self.gemini_loader = GeminiLoader()
        print("[CATALOG_SERVICE] Initialized")
    
    def update_catalog(self) -> None:
        """Update catalog JSON file with models from libraries.
        
        Should be called on server startup to discover available models.
        """
        print("[CATALOG] Updating catalog from libraries...")
        
        try:
            # Discover STT models
            stt_models = _get_whisper_models()
            
            # Discover LM models
            try:
                lm_models = self.gemini_loader.list_available_models()
            except Exception as e:
                print(f"[CATALOG] Could not fetch Gemini models ({e}), using fallback")
                lm_models = _get_gemini_models_fallback()
            
            # Build catalog structure
            catalog = {
                "STT": stt_models,
                "LM": lm_models
            }
            
            # Save to JSON file
            save_json(MODEL_CATALOG_PATH, catalog)
            
            print(f"[CATALOG] ✓ Updated: {len(stt_models)} STT, {len(lm_models)} LM models")
            print(f"[CATALOG] ✓ Saved to: {MODEL_CATALOG_PATH}")
            
        except Exception as e:
            print(f"[CATALOG] ✗ Failed to update catalog: {e}")
    
    def get_raw_catalog(self) -> dict:
        """Get raw catalog data from JSON file.
        
        Returns:
            Dictionary with 'STT' and 'LM' sections.
        """
        data = load_json(MODEL_CATALOG_PATH)
        if not isinstance(data, dict):
            return {"STT": {}, "LM": {}}
        return data
    
    def get_catalog_for_app(self) -> dict:
        """Get model catalog formatted for Flutter app.
        
        Returns only display names and enabled status.
        
        Returns:
            Dictionary with 'stt_models' and 'lm_models' arrays.
        """
        data = self.get_raw_catalog()
        
        # Convert STT models
        stt_dict = data.get("STT", {})
        stt_models = []
        if isinstance(stt_dict, dict):
            for name in stt_dict.keys():
                stt_models.append({
                    "display_name": name,
                    "enabled": True,
                    "type": "stt"
                })
        
        # Convert LM models
        lm_dict = data.get("LM", {})
        lm_models = []
        if isinstance(lm_dict, dict):
            for name in lm_dict.keys():
                if name.startswith("gemini"):
                    lm_models.append({
                        "display_name": name,
                        "enabled": True,
                        "type": "lm"
                    })
        
        return {
            "stt_models": stt_models,
            "lm_models": lm_models
        }
    
    def resolve_stt_model(self, requested_name: str) -> Tuple[str, str]:
        """Resolve STT model name to (model_name, repo_url).
        
        Args:
            requested_name: Model name from catalog STT section.
        
        Returns:
            Tuple of (model_name, repo_url).
        
        Raises:
            ValueError: If model name not found in catalog.
        """
        catalog = self.get_raw_catalog()
        stt = catalog.get("STT")
        
        if not isinstance(stt, dict):
            raise ValueError("STT section not found in model catalog")
        
        if not requested_name:
            raise ValueError("STT model name is required")
        
        if requested_name not in stt:
            raise ValueError(
                f"STT model '{requested_name}' not found. Available: {list(stt.keys())}"
            )
        
        return requested_name, stt[requested_name]
    
    def resolve_lm_model(self, requested_name: str = None) -> str:
        """Resolve LM model name to full identifier.
        
        Args:
            requested_name: Optional model name from catalog LM section.
        
        Returns:
            Full model identifier (e.g., 'models/gemini-2.5-flash').
        """
        catalog = self.get_raw_catalog()
        lm = catalog.get("LM")
        
        if not isinstance(lm, dict):
            return "models/gemini-2.5-flash"
        
        # If specific model requested and found, use it
        if requested_name and requested_name in lm:
            return lm[requested_name]
        
        # Otherwise, try preferred models
        for candidate in ("gemini-flash-latest", "gemini-2.5-flash", "gemini-2.5-pro"):
            if candidate in lm:
                return lm[candidate]
        
        # Fallback to first available model
        for _k, v in lm.items():
            return v
        
        return "models/gemini-2.5-flash"
