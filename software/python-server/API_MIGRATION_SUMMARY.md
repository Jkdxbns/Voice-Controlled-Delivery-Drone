# API Route Migration Summary

## Changes Made

All API routes have been successfully renamed to follow a more organized naming convention:

### Route Changes

| Old Route | New Route | Purpose |
|-----------|-----------|---------|
| `/api/v1/assistant/handle` | `/lm/query` | AI assistant with two-pass pipeline (text-gen or BT control) |
| `/generate` | `/lm/generate` | Direct LM text generation |
| `/transcribe` | `/stt/transcribe` | Audio transcription only |
| `/process` | `/ai/process` | Combined STT + LM processing |

### Rationale

- **`/lm/*`** - Routes that primarily use Language Model
  - `/lm/query` - Main assistant endpoint using LM for both text generation and BT control
  - `/lm/generate` - Direct LM generation without categorization

- **`/stt/*`** - Routes that primarily use Speech-to-Text
  - `/stt/transcribe` - Pure transcription without LM

- **`/ai/*`** - Routes that use both STT and LM
  - `/ai/process` - Unified endpoint combining transcription and generation

## Files Modified

### Server Side (Python/Flask)
1. `routes/assistant_routes.py` - Updated `/api/v1/assistant/handle` → `/lm/query`
2. `routes/lm_routes.py` - Updated 3 routes:
   - `/generate` → `/lm/generate`
   - `/transcribe` → `/stt/transcribe`
   - `/process` → `/ai/process`
3. `main.py` - Updated endpoint list display
4. `scripts/test_assistant_endpoint.py` - Updated test script (4 occurrences)
5. `scripts/test_server.py` - Updated test script (3 occurrences)

### Flutter App Side (Dart)
1. `lib/core/constants/api_endpoints.dart` - Updated endpoint constants
2. `lib/services/api/assistant_api_service.dart` - Updated to use `/lm/query`
3. `lib/services/api/transcription_api_service.dart` - Updated to use `/stt/transcribe` via ApiEndpoints constant

## Verification

### Test Results ✅

All routes tested and verified working:
- ✓ `/health` - Health check endpoint
- ✓ `/catalog` - Model catalog retrieval
- ✓ `/lm/generate` - Direct text generation
- ✓ `/lm/query` (text-gen) - Streaming text generation
- ✓ `/lm/query` (bt-control) - Bluetooth control commands
- ✓ `/stt/transcribe` - (via ApiEndpoints.transcribe)
- ✓ `/ai/process` - (via ApiEndpoints.process)

### Server Output
```
FlaskServer_v6 is running!
Endpoints: /health, /catalog, /device/*, /lm/generate, /lm/query, /stt/transcribe, /ai/process
```

## Updated API Table

| **Route** | **Method** | **Input** | **Output** |
|-----------|----------|-----------|------------|
| `/health` | GET | None | `{"status": "ok"}` |
| `/catalog` | GET | None | `{"status": "success", "data": {...models...}}` |
| `/lm/generate` | POST | `{"prompt": str, "model_name": str?, "stream": bool?}` | JSON or SSE stream |
| `/lm/query` | POST | `{"user_query": str, "source_device_mac": str, "lm_model": str?}` | JSON (bt-control) or SSE stream (text-gen) |
| `/stt/transcribe` | POST | Form-data: `audio` (file), `stt_model_name`, `language` | `{"status": "success", "transcription": str}` |
| `/ai/process` | POST | Audio (multipart) or Text (JSON) with STT+LM params | JSON or SSE stream |

## Next Steps

1. ✅ Server routes updated
2. ✅ Flutter app constants updated
3. ✅ API services updated
4. ✅ Test scripts updated
5. ✅ All routes verified working

The migration is complete and all endpoints are operational!
