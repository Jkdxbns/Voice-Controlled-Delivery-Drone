"""
FlaskServer_v6 - Speech-to-Text and Language Model API Server

This server provides REST API endpoints for:
- Speech-to-text transcription (Whisper)
- Text generation (Gemini LM)
- Device tracking and management
- Model catalog access
- Real-time WebSocket communication

Architecture:
- config/: Configuration and settings
- core/: Model loaders and utilities
- services/: Business logic layer
- routes/: HTTP endpoint handlers
- models/: Data models and persistence
"""

import time
import threading
import re
from flask import Flask, request
from flask_socketio import SocketIO, emit

# Import configuration
from config import DEVICE_REGISTRY_PATH

# Import models
from models.device_model import DeviceRegistry
import models.device_model as registry_module

# Import services
from services.catalog_service import CatalogService
from services.device_service import DeviceService
from services.websocket_service import websocket_service
from services.arm_execution_service import arm_execution_service
from services.audit_log import audit_event

# Import route blueprints
from routes import health_routes, device_routes, lm_routes
from routes import assistant_routes, heartbeat_routes, file_routes


app = Flask(__name__)
app.config['SECRET_KEY'] = 'coffin-secret-key'

# Initialize SocketIO with eventlet for async support
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# Initialize device registry
print("[MAIN] Initializing device registry...")
registry_module.device_registry = DeviceRegistry(DEVICE_REGISTRY_PATH)
device_service = DeviceService(registry_module.device_registry)

# Initialize WebSocket service with dependencies
websocket_service.set_socketio(socketio)
websocket_service.set_device_registry(registry_module.device_registry)

# Initialize catalog service
catalog_service = CatalogService()


# Background thread to update device statuses
def status_monitor_thread():
    """Background thread to mark devices as offline when inactive."""
    while True:
        try:
            time.sleep(60)  # Check every minute
            device_service.update_statuses()
        except Exception as e:
            print(f"[MAIN] Status monitor error: {e}")


# Middleware to auto-register and track device activity
@app.before_request
def track_device_activity():
    """Auto-register device and update last_seen timestamp on each request.
    
    Uses MAC address as primary device identifier.
    """
    if request.endpoint and request.endpoint != 'static':
        mac_address = request.headers.get('X-Device-MAC')
        
        # If device already registered, update last_seen
        if mac_address and registry_module.device_registry.get_device(mac_address):
            device_service.update_activity(mac_address)
        else:
            # Try to auto-register from headers
            device_service.auto_register_from_headers(
                headers=dict(request.headers),
                ip_address=request.remote_addr
            )


# Register blueprints
app.register_blueprint(health_routes.bp)
app.register_blueprint(device_routes.bp)
app.register_blueprint(lm_routes.bp)
app.register_blueprint(assistant_routes.bp)
app.register_blueprint(heartbeat_routes.bp)
app.register_blueprint(file_routes.bp)


# =============================================================================
# WebSocket Event Handlers
# =============================================================================

@socketio.on('connect')
def handle_connect():
    """Handle client connection."""
    print(f"\n[WEBSOCKET] ========================================")
    print(f"[WEBSOCKET] Client connected!")
    print(f"[WEBSOCKET] Socket ID: {request.sid}")
    print(f"[WEBSOCKET] Remote Address: {request.remote_addr}")
    print(f"[WEBSOCKET] ========================================")
    emit('connected', {'status': 'connected', 'message': 'Connection established'})


@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection."""
    print(f"\n[WEBSOCKET] Client disconnecting: {request.sid}")
    disconnected_mac = websocket_service.unregister_client(request.sid)
    if disconnected_mac:
        print(f"[WEBSOCKET] Device {disconnected_mac} marked as disconnected")


@socketio.on('register')
def handle_register(data):
    """Handle device registration.
    
    Expected data:
    {
        "mac_address": "XX:XX:XX:XX:XX:XX",
        "device_id": "device-xxx",
        "device_name": "samsung SM-A356E",
        "model_name": "SM-A356E"
    }
    """
    print(f"\n[WEBSOCKET] Register event received: {data}")
    audit_event("websocket_events", "register_received", socket_id=request.sid, remote_addr=request.remote_addr, payload=data)
    
    mac_address = data.get('mac_address')
    device_id = data.get('device_id')
    device_name = data.get('device_name', 'Unknown Device')
    model_name = data.get('model_name', 'Unknown')
    
    if not mac_address:
        emit('error', {'code': 'MISSING_MAC', 'message': 'MAC address required'})
        return
    
    # Register client
    client = websocket_service.register_client(
        socket_id=request.sid,
        mac_address=mac_address,
        device_id=device_id or '',
        device_name=device_name,
        model_name=model_name,
        ip_address=request.remote_addr or ''
    )
    
    # Also register/update in device registry
    if registry_module.device_registry:
        registry_module.device_registry.register_device(
            device_id=device_id or f'ws-{mac_address}',
            device_name=device_name,
            model_name=model_name,
            ip_address=request.remote_addr or '',
            mac_address=mac_address
        )
    
    emit('registered', {
        'status': 'success',
        'mac_address': mac_address,
        'message': f'Device registered: {device_name}'
    })
    audit_event("websocket_events", "register_completed", socket_id=request.sid, mac_address=mac_address, device_name=device_name, model_name=model_name)
    
    print(f"[WEBSOCKET] Device registered successfully: {device_name} ({mac_address})")


@socketio.on('bt_update')
def handle_bt_update(data):
    """Handle Bluetooth device connection update.
    
    Expected data:
    {
        "connected_devices": [
            {"mac": "BT_MAC_1", "name": "drone"},
            {"mac": "BT_MAC_2", "name": "robot"}
        ]
    }
    OR legacy format:
    {
        "connected_devices": ["BT_MAC_1", "BT_MAC_2"]
    }
    """
    print(f"\n[WEBSOCKET] BT update received: {data}")
    audit_event("websocket_events", "bt_update_received", socket_id=request.sid, payload=data)
    
    # Get parent MAC from socket
    client = websocket_service.get_client_by_socket(request.sid)
    if not client:
        emit('error', {'code': 'NOT_REGISTERED', 'message': 'Device not registered'})
        return
    
    bt_devices_raw = data.get('connected_devices', [])
    bt_macs = []
    
    # Process BT devices - register them in device registry
    for bt_device in bt_devices_raw:
        if isinstance(bt_device, dict):
            # New format with name and type
            bt_mac = bt_device.get('mac', '')
            bt_name = bt_device.get('name', 'Unknown BT Device')
            bt_type = bt_device.get('type', 'ble')  # 'ble' or 'classic'
            model_name = 'BT Classic' if bt_type == 'classic' else 'BLE'
        else:
            # Legacy format - just MAC string
            bt_mac = bt_device
            bt_name = f'BT Device {bt_mac[-8:]}'  # Use last 8 chars of MAC as name
            model_name = 'BLE'  # Default to BLE
        
        if bt_mac:
            bt_macs.append(bt_mac)
            
            # Register BT device in device registry with parent reference
            if registry_module.device_registry:
                registry_module.device_registry.register_device(
                    device_id=f'bt-{bt_mac}',
                    device_name=bt_name,
                    model_name=model_name,
                    ip_address='',
                    mac_address=bt_mac,
                    device_type='bluetooth',
                    parent_device=client.mac_address
                )
                print(f"[WEBSOCKET] Registered BT device: {bt_name} ({bt_mac}) [{model_name}] -> parent: {client.device_name}")
    
    websocket_service.update_bt_devices(client.mac_address, bt_macs)
    audit_event("websocket_events", "bt_update_completed", parent_mac=client.mac_address, parent_name=client.device_name, bt_macs=bt_macs)
    
    emit('bt_update_ack', {
        'status': 'success',
        'bt_devices_count': len(bt_macs)
    })


@socketio.on('bt_command')
def handle_bt_command(data):
    """Handle direct Bluetooth command routing.
    
    This bypasses AI processing and directly routes a command to a BT device.
    
    Expected data:
    {
        "target_bt_mac": "XX:XX:XX:XX:XX:XX",
        "command": "led:on"
    }
    """
    print(f"\n[WEBSOCKET] Direct BT command: {data}")
    
    # Get source device
    client = websocket_service.get_client_by_socket(request.sid)
    if not client:
        emit('error', {'code': 'NOT_REGISTERED', 'message': 'Device not registered'})
        return
    
    target_bt_mac = data.get('target_bt_mac', '')
    command = data.get('command', '')
    
    if not target_bt_mac:
        emit('error', {'code': 'MISSING_TARGET', 'message': 'Target BT MAC required'})
        return
    
    if not command:
        emit('error', {'code': 'MISSING_COMMAND', 'message': 'Command required'})
        return
    
    # Find which phone has this BT device connected
    destination_mac = websocket_service.find_destination_for_bt_command(target_bt_mac)
    
    if not destination_mac:
        emit('error', {
            'code': 'BT_DEVICE_NOT_CONNECTED',
            'message': f'No device has Bluetooth device {target_bt_mac} connected'
        })
        return
    
    # Get BT device info from registry for name
    bt_device_name = target_bt_mac
    if registry_module.device_registry:
        bt_device = registry_module.device_registry.get_device(target_bt_mac)
        if bt_device:
            bt_device_name = bt_device.get('device_name', target_bt_mac)
    
    # Create task payload
    task_payload = {
        'task': 'bt-control',
        'target-device': f'{bt_device_name} (MAC: {target_bt_mac})',
        'command': command,
        '_routed_from': client.mac_address,
        '_routed_from_name': client.device_name
    }
    
    # Route to the device that has the BT device connected
    print(f"[WEBSOCKET] Routing command '{command}' to {destination_mac} for BT device {target_bt_mac}")
    websocket_service.emit_task(destination_mac, task_payload)
    
    # Notify source that command was routed
    emit('command_routed', {
        'status': 'success',
        'message': 'Command routed to device with BT connection',
        'target_bt_device': target_bt_mac,
        'routed_to': destination_mac
    })


@socketio.on('assistant_request')
def handle_assistant_request(data):
    """Handle assistant request via WebSocket.
    
    Expected data:
    {
        "query": "turn on drone LED",
        "lm_model": "gemini-2.5-flash-lite"  // optional
    }
    """
    print(f"\n[WEBSOCKET] Assistant request: {data}")
    audit_event("assistant_pipeline", "assistant_request_ws", socket_id=request.sid, payload=data)
    
    # Get source device
    client = websocket_service.get_client_by_socket(request.sid)
    if not client:
        emit('error', {'code': 'NOT_REGISTERED', 'message': 'Device not registered'})
        return
    
    query = data.get('query', '')
    lm_model = data.get('lm_model')
    
    if not query:
        emit('error', {'code': 'EMPTY_QUERY', 'message': 'Query cannot be empty'})
        return
    
    # Import here to avoid circular imports
    from services.assistant_service import AssistantService
    
    # Create assistant service instance
    assistant = AssistantService(registry_module.device_registry)
    
    # Process request
    result = assistant.handle_request(
        user_query=query,
        source_device_mac=client.mac_address,
        lm_model=lm_model
    )
    
    # Handle streaming response (text-generation)
    if result.get('use_streaming'):
        emit('response', {
            'type': 'streaming',
            'message': 'Use HTTP endpoint for streaming text generation'
        })
        return
    
    # Handle bt-control or other task responses
    if result.get('status') == 'success':
        task_result = result.get('result', {})
        task_type = task_result.get('task', 'unknown')
        
        # Determine destination based on task type
        if task_type == 'bt-control':
            # Extract target BT device MAC from response
            target_device_str = task_result.get('target-device', '')
            target_mac = _extract_mac(target_device_str)
            
            if target_mac:
                # Find which phone has this BT device connected
                destination_mac = websocket_service.find_destination_for_bt_command(target_mac)
                
                if destination_mac:
                    # Route to the device that has the BT device connected
                    task_result['_routed_from'] = client.mac_address
                    task_result['_routed_from_name'] = client.device_name
                    
                    websocket_service.emit_task(destination_mac, task_result)
                    audit_event(
                        "arm_pipeline",
                        "assistant_request_routed_task",
                        source_mac=client.mac_address,
                        source_name=client.device_name,
                        destination_mac=destination_mac,
                        target_bt_mac=target_mac,
                        task=task_result,
                    )
                    
                    # Also notify source that command was routed
                    emit('command_routed', {
                        'status': 'success',
                        'message': f'Command routed to device with BT connection',
                        'target_bt_device': target_mac,
                        'routed_to': destination_mac
                    })
                    return
                else:
                    # BT device not connected to any online device
                    emit('error', {
                        'code': 'BT_DEVICE_NOT_CONNECTED',
                        'message': f'No device has Bluetooth device {target_mac} connected'
                    })
                    return
        
        # Default: send response back to source
        emit('task', task_result)
    
    elif result.get('status') == 'error':
        emit('error', result.get('error', {'code': 'UNKNOWN', 'message': 'Unknown error'}))
    
    else:
        emit('response', result)


@socketio.on('arm_status')
def handle_arm_status(data):
    """Handle arm execution status updates from a Jetson/edge controller.

    Expected data:
    {
        "status": "received|executing|done|error",
        "message": "human readable status",
        "command": "optional command string",
        "_routed_from": "optional source device MAC"
    }
    """
    client = websocket_service.get_client_by_socket(request.sid)
    if not client:
        emit('error', {'code': 'NOT_REGISTERED', 'message': 'Device not registered'})
        return

    payload = {
        'status': data.get('status', 'unknown'),
        'message': data.get('message', ''),
        'command': data.get('command', ''),
        'plan_id': data.get('plan_id', ''),
        'step_id': data.get('step_id', ''),
        'command_id': data.get('command_id', ''),
        'details': data.get('details', ''),
        'from_mac': client.mac_address,
        'from_name': client.device_name,
        'timestamp': time.time(),
    }

    # Feed command status updates into step executor waiters.
    arm_execution_service.update_status(payload)
    audit_event("arm_feedback", "arm_status", payload=payload)

    source_mac = data.get('_routed_from') or data.get('routed_from')
    routed = False
    if source_mac and websocket_service.is_client_connected(source_mac):
        routed = websocket_service.emit_to_device(source_mac, 'arm_status', payload)

    print(
        f"[WEBSOCKET] arm_status from {client.device_name} ({client.mac_address}): "
        f"{payload['status']} | {payload['message']} "
        f"| plan_id={payload.get('plan_id') or '-'} "
        f"step_id={payload.get('step_id') or '-'} "
        f"command_id={payload.get('command_id') or '-'}"
    )

    emit('arm_status_ack', {
        'status': 'success',
        'routed': routed,
    })
    audit_event(
        "arm_feedback",
        "arm_status_ack_sent",
        target_mac=client.mac_address,
        source_mac=source_mac,
        ack_payload={'status': 'success', 'routed': routed},
        arm_payload=payload,
    )


def _extract_mac(device_string: str) -> str:
    """Extract MAC address from device string format."""
    if not device_string:
        return ''
    match = re.search(r'MAC:\s*([A-F0-9:]{17})', device_string, re.IGNORECASE)
    return match.group(1) if match else ''


@socketio.on('ping_server')
def handle_ping(data=None):
    """Simple ping to keep connection alive and update device activity."""
    # Update last_seen for this device to keep it marked as online
    client = websocket_service.get_client_by_socket(request.sid)
    if client and registry_module.device_registry:
        registry_module.device_registry.update_last_seen(client.mac_address)
    emit('pong', {'timestamp': time.time()})


if __name__ == "__main__":
    # Update catalog from libraries before starting server
    print("[MAIN] Updating model catalog...")
    catalog_service.update_catalog()
    
    # Print device registry stats
    stats = device_service.get_stats()
    print(f"[MAIN] Loaded devices: {stats['total_devices']} total, "
          f"{stats['online_devices']} online, {stats['offline_devices']} offline")
    
    # Start background status monitor thread
    monitor = threading.Thread(target=status_monitor_thread, daemon=True)
    monitor.start()
    print("[MAIN] Status monitor thread started")
    
    # Start server with SocketIO (eventlet)
    print("\n" + "="*50)
    print("FlaskServer_v6 is running!")
    print("HTTP Endpoints: /health, /catalog, /device/*, /lm/generate, /lm/query, /stt/transcribe, /ai/process")
    print("WebSocket: ws://0.0.0.0:5000 (events: register, bt_update, assistant_request)")
    print("="*50 + "\n")
    
    # Use socketio.run instead of app.run for WebSocket support
    socketio.run(app, host="0.0.0.0", port=5000, debug=True, use_reloader=True)
