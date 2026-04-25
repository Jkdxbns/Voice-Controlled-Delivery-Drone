# Flask AI Assistant Server

**Version:** 8.0  
**Last Updated:** November 14, 2025  
**Status:** ✅ Ready

A powerful Flask-based REST API server providing Speech-to-Text transcription, AI assistant capabilities with intelligent task categorization, device management, and Bluetooth control integration.

---

## 🚀 Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Configure Gemini API key
echo {"gemini_api_key": "YOUR_KEY"} > secrets/apis.json

# Run server
python main.py
```

**Server runs on**: `http://0.0.0.0:5000`

---

## ✨ Key Features

### 🎤 Speech-to-Text
- **Whisper Model Integration**: Multiple model sizes (tiny, base, small, medium)
- **Fast Processing**: Using faster-whisper (4x faster than original)
- **Multi-language Support**: English and multilingual options
- **CPU & GPU Support**: Automatic CUDA detection

### 🤖 AI Assistant
- **Two-Pass Architecture**: prompt categorization → specialized processing
- **Task Categories**:
  - **Text Generation**: Conversational responses with streaming
  - **Bluetooth Control**: Device command generation with validation
- **Smart Context Injection**: Device registry provided only when needed
- **Format Validation**: Retry mechanism for command accuracy

### 📱 Device Management
- **Auto-Registration**: Devices register automatically via headers
- **MAC Address Tracking**: Hardware-based identification
- **Status Monitoring**: Real-time online/offline tracking (2-minute timeout)
- **Heartbeat System**: 60-second periodic updates keep devices online
- **Connection Events**: Immediate status updates on BT connect/disconnect
- **Custom Names**: User-assignable device names with sync

### 🔌 Bluetooth Control
- **Device Registry**: JSON-based device catalog with MAC addresses
- **Output Format Validation**: Configurable command formats per device/actuator
- **Command Generation**: Gemini-powered natural language → device command
- **Retry Logic**: Automatic correction for invalid commands

### 🔄 Real-Time Streaming
- **Server-Sent Events (SSE)**: Live response streaming
- **Status Updates**: Progress notifications during processing
- **Chunked Responses**: Immediate display of generated text

---

## 🏗️ Architecture

### Project Structure

```
FlaskServer_v8/
├── main.py                          # Application entry point
├── requirements.txt                 # Python dependencies
├── device_registry.json             # Device tracking & status
│
├── config/                          # Configuration layer
│   ├── settings.py                  # Server settings & paths
│   └── secrets.py                   # API key management
│
├── services/                        # Business logic layer
│   ├── assistant_service.py         # Two-pass AI assistant logic
│   ├── device_service.py            # Device management
│   ├── stt_service.py               # Speech-to-text operations
│   ├── lm_service.py                # Language model generation
│   └── catalog_service.py           # Model catalog
│
├── core/                            # Core utilities
│   ├── whisper_loader.py            # Whisper model loading
│   ├── gemini_loader.py             # Gemini API initialization
│   └── utils.py                     # Helper functions
│
├── models/                          # Data models
│   ├── device_model.py              # Device registry persistence
│   ├── model_catalog.json           # Available AI models
│   └── __models__/                  # Whisper model cache
│
├── routes/                          # API endpoints
│   ├── health_routes.py             # Health check & catalog
│   ├── assistant_routes.py          # AI assistant endpoint
│   ├── device_routes.py             # Device management
│   ├── heartbeat_routes.py          # Device heartbeat & status
│   └── lm_routes.py                 # Legacy STT+LM endpoint
│
├── prompt_templates/                # AI prompts
│   ├── pass1_categorization.txt     # Task categorization
│   ├── pass2_task_prompts.json      # Task-specific prompts
│   └── task_schemas.json            # Response schemas
│
├── scripts/                         # Testing & utilities
│   ├── test_assistant_endpoint.py   # Assistant API tests
│   ├── test_device_lookup.py        # Device tracking tests
│   └── download_whisper_models.py   # Model downloader
│
└── secrets/                         # API keys (gitignored)
    └── apis.json                    # Gemini API key
```

### Architectural Layers

1. **Configuration** (`config/`): Centralized settings and secrets
2. **Services** (`services/`): Business logic, isolated and testable
3. **Core** (`core/`): Reusable utilities and model loaders
4. **Routes** (`routes/`): Thin HTTP controllers, delegate to services
5. **Models** (`models/`): Data persistence and schemas

---

## 🔌 API Endpoints

### Core Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Server health check |
| `/catalog` | GET | Available STT and LM models |

### AI Assistant

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/assistant/handle` | POST | Two-pass AI assistant (text generation or BT control) |

**Request (Text Generation)**:
```json
{
  "user_query": "What is photosynthesis?"
}
```

**Response**: SSE stream with generated text chunks

**Request (Bluetooth Control)**:
```json
{
  "user_query": "turn on the <your_bt_device_custom_name> lights"
}
```

**Response**:
```json
{
  "task": "bt-control",
  "target-device": "<your_bt_device_custom_name> (MAC: A1:B2:C3:D4:E5:F6)",
  "output": {
    "actuator": "lights",
    "generated_output": "ON"
  }
}
```

### Device Management

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/device/list` | GET | Get all registered devices |
| `/device/<id>/name` | PUT | Update device custom name |
| `/device/<id>/name` | DELETE | Clear device custom name |
| `/device/heartbeat` | POST | Device heartbeat (keeps online) |
| `/device/connection-status` | POST | Report BT connect/disconnect |

### Legacy Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/process` | POST | Audio/text processing (STT + LM) |
| `/generate` | POST | Direct LM text generation |

---

## 🧠 AI Assistant System

### Two-Pass Architecture

**Pass 1: Categorization**
- Input: User query (e.g., "turn on drone lights")
- Output: Task category (`text-generation` or `bt-control`)
- **Key Feature**: NO device list provided → reduces token cost

**Pass 2: Specialized Processing**

**For Text Generation**:
- Streams conversational response via SSE
- Returns chunk-by-chunk for immediate display

**For Bluetooth Control**:
- Device registry injected (only when needed)
- Generates structured command JSON
- Validates against device output formats
- Retries if command invalid (up to 3 attempts)

### Task Categorization

**text-generation**: General questions, conversations, information requests
- Examples: "What is gravity?", "Tell me a joke", "Explain quantum physics"

**bt-control**: Device control commands
- Examples: "turn on lights", "start the motor", "set color to red"

### Device Registry Format

```json
{
  "A1:B2:C3:D4:E5:F6": {
    "name": "Drone Controller",
    "type": "bluetooth",
    "output_formats": {
      "lights": ["ON", "OFF"],
      "motor": ["START", "STOP", "FORWARD", "BACKWARD"]
    }
  }
}
```

---

## 📦 Installation & Setup

### Prerequisites
- **Python**: 3.8 or higher
- **Storage**: 3+ GB for Whisper models + 3GB for virtual-env
- **Gemini API Key**: Get from https://makersuite.google.com/app/apikey

### Installation Steps

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Configure Gemini API key
mkdir secrets
echo {"gemini_api_key": "YOUR_GEMINI_API_KEY"} > secrets/apis.json

# 3. (Optional) Pre-download Whisper models
python scripts/download_whisper_models.py

# 4. Start server
python main.py
```

### Verify Installation

```bash
# Health check
curl http://localhost:5000/health

# Get model catalog
curl http://localhost:5000/catalog
```

---

## 🧪 Testing

### Run Test Scripts

```bash
# Test AI assistant endpoint
python scripts/test_assistant_endpoint.py

# Test device tracking
python scripts/test_device_lookup.py

# Test all routes
scripts\test_all_routes.bat
```

### Manual Testing Examples

```bash
# Text generation
curl -X POST http://localhost:5000/api/v1/assistant/handle \
  -H "Content-Type: application/json" \
  -d "{\"user_query\": \"What is an apple?\"}"

# Bluetooth control
curl -X POST http://localhost:5000/api/v1/assistant/handle \
  -H "Content-Type: application/json" \
  -d "{\"user_query\": \"turn on drone lights\"}"
```

---

## ⚙️ Configuration

### Server Settings

Edit `main.py`:
```python
app.run(
    host="0.0.0.0",  # Listen on all interfaces
    port=5000,       # Port number
    debug=False      # Production: False, Development: True
)
```

### Environment Variables

```bash
# Gemini API Key (alternative to apis.json)
export GEMINI_API_KEY="your_key_here"
```

### Firewall Configuration (Windows)

```bash
# Allow incoming connections on port 5000
netsh advfirewall firewall add rule name="Flask Server" dir=in action=allow protocol=TCP localport=5000
```

---

## 📱 Mobile App Integration

1. **Configure Server URL** in app settings:
   - Host: Your server IP (e.g., `192.168.0.168`)
   - Port: `5000`

2. **Device Headers**: App must send:
   ```
   X-Device-Id: <uuid>
   X-Device-Name: <device name>
   X-Device-Model: <model>
   X-Device-MAC: <MAC address>
   ```

3. **Heartbeat**: App should POST to `/device/heartbeat` every 60 seconds

---

## 🐛 Troubleshooting

### "Gemini API error"
- Verify API key in `secrets/apis.json`
- Check quota at https://makersuite.google.com/
- Try switching model in `gemini_loader.py`

### "Device not found" error
- Check `device_registry.json` has device entry
- Verify MAC address matches exactly
- Ensure device name in query matches registry

### Devices going offline
- Check app sends heartbeat every 60 seconds
- Verify heartbeat route working: check server logs
- Status timeout is 2 minutes (configurable in `device_model.py`)

---

## 📊 Performance

### Whisper STT
- **CPU**: ~2-5 seconds per 10 sec audio
- **GPU (CUDA)**: ~0.5-2 seconds per 10 sec audio

### Gemini LM
- **Streaming**: Immediate response display
- **First token**: ~1-3 seconds
- **Cost optimization**: Two-pass reduces tokens by ~60%

---

## 🔒 Security Considerations

### Development (Current)
✅ Fine for local network testing
✅ Use Tailscale or similar VPN service for cross-network connection


---

**Ready to serve intelligent AI assistance! 🚀**

