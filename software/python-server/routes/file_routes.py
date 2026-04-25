"""File routes for cross-device file transfer."""

from flask import Blueprint, request, jsonify, send_file
import models.device_model as registry_module

from services.file_cache_service import FileCacheService
from services.websocket_service import WebSocketService

bp = Blueprint('files', __name__)
file_cache = FileCacheService()


@bp.route('/files/upload', methods=['POST'])
def upload_file():
    try:
        file_cache.cleanup_expired()

        if 'file' not in request.files:
            return jsonify({"status": "error", "message": "Missing file"}), 400

        file_storage = request.files['file']
        original_name = request.form.get('file_name') or file_storage.filename or 'file'
        source_mac = request.form.get('source_mac', '')
        target_mac = request.form.get('target_mac', '')
        action = request.form.get('action', 'copy')
        client_checksum = request.form.get('checksum')

        if not source_mac or not target_mac:
            return jsonify({"status": "error", "message": "Missing source or target MAC"}), 400

        metadata = file_cache.save_upload(
            file_storage=file_storage,
            original_name=original_name,
            source_mac=source_mac,
            target_mac=target_mac,
            action=action,
            checksum=client_checksum
        )

        # Notify target device if connected
        websocket_service = WebSocketService()
        target_connected = websocket_service.is_client_connected(target_mac)

        if target_connected:
            source_device = registry_module.device_registry.get_device(source_mac) if registry_module.device_registry else None
            source_name = source_device.get('custom_name') or source_device.get('device_name', 'Unknown') if source_device else 'Unknown'

            task = {
                "task": "file-transfer-ready",
                "processing-device": "server",
                "source-device": source_name,
                "target-device": target_mac,
                "output": {
                    "file_id": metadata['file_id'],
                    "file_name": metadata['original_name'],
                    "checksum": metadata['checksum'],
                    "size": metadata['size'],
                    "source_name": source_name,
                    "action": action
                },
                "_routed_from": source_mac,
                "_routed_from_name": source_name
            }

            websocket_service.emit_task(target_mac, task)

        return jsonify({
            "status": "ok",
            "file_id": metadata['file_id'],
            "checksum": metadata['checksum'],
            "size": metadata['size'],
            "target_connected": target_connected
        }), 200

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@bp.route('/files/download/<file_id>', methods=['GET'])
def download_file(file_id: str):
    try:
        file_cache.cleanup_expired()
        metadata = file_cache.get_metadata(file_id)
        if not metadata:
            return jsonify({"status": "error", "message": "File not found"}), 404

        file_path = file_cache.get_file_path(file_id)
        if not file_path:
            return jsonify({"status": "error", "message": "File missing"}), 404

        return send_file(
            file_path,
            as_attachment=True,
            download_name=metadata.get('original_name', 'file')
        )

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
