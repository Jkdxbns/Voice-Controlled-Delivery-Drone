"""Health and catalog endpoints."""

from flask import Blueprint, jsonify
from services.catalog_service import CatalogService
from services.websocket_service import WebSocketService

bp = Blueprint("health", __name__)

# Initialize catalog service
catalog_service = CatalogService()


@bp.get("/catalog")
def catalog():
    """Return the model catalog with status wrapper."""
    catalog_data = catalog_service.get_catalog_for_app()
    return jsonify({"status": "success", "data": catalog_data}), 200


@bp.get("/health")
def health():
    """Health check endpoint."""
    return jsonify(status="ok"), 200


@bp.get("/websocket/status")
def websocket_status():
    """Return WebSocket connection status and connected clients."""
    ws_service = WebSocketService()
    clients = ws_service.get_all_clients()
    
    client_info = []
    for client in clients:
        client_info.append({
            "mac_address": client.mac_address,
            "device_name": client.device_name,
            "model_name": client.model_name,
            "ip_address": client.ip_address,
            "bt_devices": client.bt_devices,
            "connected_at": client.connected_at.isoformat() if client.connected_at else None
        })
    
    return jsonify({
        "status": "success",
        "connected_clients": len(clients),
        "clients": client_info
    }), 200
