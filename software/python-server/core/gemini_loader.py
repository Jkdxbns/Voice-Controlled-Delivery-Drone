"""Gemini LM model initialization and configuration."""

try:
    import google.generativeai as gemini
    _gemini_import_error = None
except Exception as e:
    gemini = None
    _gemini_import_error = e

from config import get_api_key


class GeminiLoader:
    """Manages Gemini language model initialization (Singleton)."""
    
    _instance = None
    
    def __new__(cls):
        """Ensure only one instance exists."""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """Initialize the Gemini loader (only once)."""
        if self._initialized:
            return
        self._initialized = True
        self._configured = False
        print("[GEMINI] Initialized loader")
    
    def get_model(self, model_identifier: str):
        """Get a Gemini GenerativeModel instance.
        
        Args:
            model_identifier: Full model identifier (e.g., 'models/gemini-2.5-flash')
        
        Returns:
            Configured GenerativeModel instance.
        
        Raises:
            RuntimeError: If API key not configured or library not installed.
        """
        if gemini is None:
            raise RuntimeError(
                f"google-generativeai not available: {_gemini_import_error!r}. "
                "Install with: pip install google-generativeai"
            )
        
        # Configure API key (only once)
        if not self._configured:
            api_key = get_api_key()
            if not api_key:
                raise RuntimeError(
                    "Gemini API key not configured. Set GEMINI_API_KEY or secrets/apis.json"
                )
            gemini.configure(api_key=api_key)
            self._configured = True
            print("[GEMINI] ✓ API configured")
        
        return gemini.GenerativeModel(model_identifier)
    
    def list_available_models(self) -> dict:
        """List all available Gemini models from API.
        
        Returns:
            Dictionary mapping display names to model identifiers.
        
        Raises:
            RuntimeError: If API not accessible.
        """
        if gemini is None:
            raise RuntimeError("google-generativeai not installed")
        
        # Configure if not already done
        if not self._configured:
            api_key = get_api_key()
            if not api_key:
                raise RuntimeError("No API key configured")
            gemini.configure(api_key=api_key)
            self._configured = True
        
        available_models = {}
        for model in gemini.list_models():
            model_name = model.name
            # Filter for generative models only
            if hasattr(model, 'supported_generation_methods') and \
               'generateContent' in model.supported_generation_methods:
                display_name = model_name.split('/')[-1] if '/' in model_name else model_name
                # Only include gemini models
                if display_name.startswith('gemini'):
                    available_models[display_name] = model_name
        
        return available_models
