"""Device Management Routes - Handles device registration and lookup."""

from flask import Blueprint, request, jsonify
from urllib.parse import unquote
import models.device_model as registry_module


bp = Blueprint("device", __name__)


@bp.post("/device/register")
def register_device():
    """Register a device with the server
    
    Request JSON:
    {
        "device_id": "uuid-string",
        "device_name": "Samsung Galaxy S21",
        "model_name": "SM-G991B",
        "mac_address": "AA:BB:CC:DD:EE:FF"  # Optional
    }
    
    Response:
    {
        "status": "success",
        "message": "Device registered",
        "device": {...device_record...}
    }
    """
    print("\n" + "="*80)
    print("[REGISTRATION] POST /device/register called")
    print("="*80)
    
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    payload = request.get_json() or {}
    
    # DEBUG: Print all headers
    print("\n[DEBUG] Request Headers:")
    for header_name, header_value in request.headers:
        print(f"  {header_name}: {header_value}")
    
    # DEBUG: Print request body
    print(f"\n[DEBUG] Request Body (JSON):")
    print(f"  Raw payload: {payload}")
    
    device_id = payload.get("device_id")
    device_name = payload.get("device_name")
    model_name = payload.get("model_name")
    mac_address = payload.get("mac_address")
    
    print(f"\n[DEBUG] Extracted Fields:")
    print(f"  device_id: {device_id}")
    print(f"  device_name: {device_name}")
    print(f"  model_name: {model_name}")
    print(f"  mac_address: {mac_address}")
    print(f"  remote_addr: {request.remote_addr}")
    
    # Validation
    if not all([device_id, device_name, model_name]):
        print(f"\n[ERROR] Validation failed - missing required fields")
        print(f"  device_id present: {bool(device_id)}")
        print(f"  device_name present: {bool(device_name)}")
        print(f"  model_name present: {bool(model_name)}")
        return jsonify(error="Missing required fields: device_id, device_name, model_name"), 400
    
    # Use client-provided IP address if available (for BT devices, this contains parent phone MAC)
    # Otherwise fall back to request IP address (for Wi-Fi devices)
    ip_address = payload.get("ip_address") or request.remote_addr
    
    # Detect if this is a Bluetooth device registration
    # BT devices have their parent phone's MAC in ip_address field
    parent_device = None
    device_type = 'android'
    
    # Check if ip_address looks like a MAC address (BT device registration)
    if ip_address and ':' in ip_address and len(ip_address) == 17:
        parent_device = ip_address
        device_type = 'bluetooth'
        ip_address = ''  # Clear IP since it's actually a MAC
        print(f"[REGISTRATION] Detected BT device with parent MAC: {parent_device}")
    
    print(f"\n[DEBUG] Registration Parameters:")
    print(f"  ip_address: {ip_address}")
    print(f"  device_type: {device_type}")
    print(f"  parent_device: {parent_device}")
    
    # Register device
    try:
        print(f"\n[REGISTRATION] Calling device_registry.register_device()...")
        device_record = registry_module.device_registry.register_device(
            device_id=device_id,
            device_name=device_name,
            model_name=model_name,
            ip_address=ip_address,
            mac_address=mac_address,
            device_type=device_type,
            parent_device=parent_device
        )
        
        print(f"[SUCCESS] Device registered successfully:")
        print(f"  Device record: {device_record}")
        print("="*80 + "\n")
        
        return jsonify({
            "status": "success",
            "message": "Device registered",
            "device": device_record
        }), 200
    
    except Exception as e:
        print(f"\n[ERROR] Registration failed: {str(e)}")
        print("="*80 + "\n")
        return jsonify(error=f"Registration failed: {str(e)}"), 500


@bp.get("/device/list")
def list_devices():
    """Get all registered devices
    
    Response:
    {
        "status": "success",
        "devices": [
            {
                "device_id": "uuid-1234",
                "device_name": "Samsung Galaxy S21",
                "model_name": "SM-G991B",
                "ip_address": "192.168.1.45",
                "mac_address": "AA:BB:CC:DD:EE:FF",
                "status": "active",
                "first_seen": "2025-11-09T10:30:00",
                "last_seen": "2025-11-09T14:22:15"
            },
            ...
        ],
        "count": 2,
        "stats": {
            "total_devices": 2,
            "active_devices": 1,
            "inactive_devices": 1
        }
    }
    """
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    try:
        # Update statuses before returning list
        registry_module.device_registry.update_device_statuses()
        
        # Also mark WebSocket-connected devices as online
        from services.websocket_service import websocket_service
        connected_macs = websocket_service.get_connected_device_macs()
        for mac in connected_macs:
            registry_module.device_registry.update_last_seen(mac)
        
        # Mark BT devices of connected parents as online too
        for mac in connected_macs:
            bt_devices = websocket_service.get_bt_devices_for_parent(mac)
            for bt_mac in bt_devices:
                registry_module.device_registry.update_last_seen(bt_mac)
        
        devices = registry_module.device_registry.get_all_devices()
        stats = registry_module.device_registry.get_stats()
        
        return jsonify({
            "status": "success",
            "devices": devices,
            "count": len(devices),
            "stats": stats
        }), 200
    
    except Exception as e:
        return jsonify(error=f"Failed to retrieve devices: {str(e)}"), 500


@bp.get("/device/<device_id>")
def get_device(device_id: str):
    """Get specific device by ID
    
    Response:
    {
        "status": "success",
        "device": {...device_record...}
    }
    """
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    try:
        device = registry_module.device_registry.get_device(device_id)
        
        if device is None:
            return jsonify(error="Device not found"), 404
        
        return jsonify({
            "status": "success",
            "device": device
        }), 200
    
    except Exception as e:
        return jsonify(error=f"Failed to retrieve device: {str(e)}"), 500


@bp.put("/device/<device_id>/name")
def update_device_name(device_id: str):
    """Update custom name for a device
    
    Request JSON:
    {
        "custom_name": "My Custom Device Name",
        "updated_by_device_id": "device-id-making-change"
    }
    
    Response:
    {
        "status": "success",
        "device": {...updated device record...},
        "message": "Device name updated"
    }
    """
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    try:
        # URL decode the device_id (Flask may not decode it automatically)
        device_id = unquote(device_id)
        
        payload = request.get_json() or {}
        
        custom_name = payload.get("custom_name")
        updated_by_device_id = payload.get("updated_by_device_id") or request.headers.get('X-Device-Id')
        
        if not custom_name:
            return jsonify(error="Missing required field: custom_name"), 400
        
        if not updated_by_device_id:
            return jsonify(error="Missing updated_by_device_id"), 400
        
        # Update device custom name
        device = registry_module.device_registry.update_device_custom_name(
            identifier=device_id,
            custom_name=custom_name,
            updated_by_device_id=updated_by_device_id
        )
        
        if device is None:
            return jsonify(error=f"Device not found: {device_id}"), 404
        
        return jsonify({
            "status": "success",
            "device": device,
            "message": "Device name updated",
            "broadcast": True
        }), 200
    
    except Exception as e:
        return jsonify(error=f"Failed to update device name: {str(e)}"), 500


@bp.delete("/device/<device_id>/name")
def clear_device_name(device_id: str):
    """Clear custom name for a device (revert to auto-detected)
    
    Response:
    {
        "status": "success",
        "device": {...updated device record...},
        "message": "Custom name cleared"
    }
    """
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    try:
        # URL decode the device_id
        device_id = unquote(device_id)
        
        device = registry_module.device_registry.clear_device_custom_name(identifier=device_id)
        
        if device is None:
            return jsonify(error=f"Device not found: {device_id}"), 404
        
        return jsonify({
            "status": "success",
            "device": device,
            "message": "Custom name cleared",
            "broadcast": True
        }), 200
    
    except Exception as e:
        return jsonify(error=f"Failed to clear device name: {str(e)}"), 500
