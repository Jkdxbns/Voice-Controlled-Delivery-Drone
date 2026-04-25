"""WebSocket Service - Manages real-time connections and device routing."""

from datetime import datetime
from typing import Dict, Optional, List, Any
from dataclasses import dataclass, field


@dataclass
class ConnectedClient:
    """Represents a connected WebSocket client."""
    socket_id: str
    mac_address: str
    device_id: str
    device_name: str
    model_name: str
    ip_address: str
    connected_at: datetime
    bt_devices: List[str] = field(default_factory=list)


class WebSocketService:
    """Manages WebSocket connections and device-to-device routing."""
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        # MAC -> ConnectedClient mapping
        self._clients: Dict[str, ConnectedClient] = {}
        
        # Socket ID -> MAC reverse lookup
        self._socket_to_mac: Dict[str, str] = {}
        
        # BT MAC -> Parent MAC mapping (which phone has this BT device connected)
        self._bt_to_parent: Dict[str, str] = {}
        
        # Device registry reference (set by main.py)
        self._device_registry = None
        
        # SocketIO instance (set by main.py)
        self._socketio = None
        
        self._initialized = True
        print("[WEBSOCKET_SERVICE] Initialized")
    
    def set_socketio(self, socketio):
        """Set SocketIO instance for emitting events."""
        self._socketio = socketio
    
    def set_device_registry(self, registry):
        """Set device registry for looking up device info."""
        self._device_registry = registry
    
    # =========================================================================
    # Connection Management
    # =========================================================================
    
    def register_client(
        self,
        socket_id: str,
        mac_address: str,
        device_id: str,
        device_name: str,
        model_name: str,
        ip_address: str
    ) -> ConnectedClient:
        """Register a new client connection.
        
        Args:
            socket_id: SocketIO session ID
            mac_address: Device MAC address (primary identifier)
            device_id: Device UUID
            device_name: Human-readable device name
            model_name: Device model
            ip_address: Client IP
        
        Returns:
            ConnectedClient instance
        """
        client = ConnectedClient(
            socket_id=socket_id,
            mac_address=mac_address,
            device_id=device_id,
            device_name=device_name,
            model_name=model_name,
            ip_address=ip_address,
            connected_at=datetime.now(),
            bt_devices=[]
        )
        
        # Remove old socket mapping if device was already connected
        if mac_address in self._clients:
            old_socket_id = self._clients[mac_address].socket_id
            if old_socket_id in self._socket_to_mac:
                del self._socket_to_mac[old_socket_id]
        
        self._clients[mac_address] = client
        self._socket_to_mac[socket_id] = mac_address
        
        # Update device registry to mark as online
        if self._device_registry:
            self._device_registry.update_last_seen(mac_address)
        
        print(f"[WEBSOCKET_SERVICE] Client registered: {device_name} ({mac_address})")
        print(f"[WEBSOCKET_SERVICE] Total connected clients: {len(self._clients)}")
        
        return client
    
    def unregister_client(self, socket_id: str) -> Optional[str]:
        """Unregister a client on disconnect.
        
        Args:
            socket_id: SocketIO session ID
        
        Returns:
            MAC address of disconnected client, or None
        """
        mac_address = self._socket_to_mac.get(socket_id)
        
        if mac_address:
            client = self._clients.get(mac_address)
            if client:
                # Clear BT device mappings for this client
                for bt_mac in client.bt_devices:
                    if bt_mac in self._bt_to_parent:
                        del self._bt_to_parent[bt_mac]
                
                print(f"[WEBSOCKET_SERVICE] Client disconnected: {client.device_name} ({mac_address})")
            
            # Remove from registries
            del self._clients[mac_address]
            del self._socket_to_mac[socket_id]
            
            print(f"[WEBSOCKET_SERVICE] Remaining clients: {len(self._clients)}")
        
        return mac_address
    
    def get_client_by_mac(self, mac_address: str) -> Optional[ConnectedClient]:
        """Get client by MAC address."""
        return self._clients.get(mac_address)
    
    def get_client_by_socket(self, socket_id: str) -> Optional[ConnectedClient]:
        """Get client by socket ID."""
        mac = self._socket_to_mac.get(socket_id)
        return self._clients.get(mac) if mac else None
    
    def is_client_connected(self, mac_address: str) -> bool:
        """Check if a client is connected."""
        return mac_address in self._clients
    
    def get_all_clients(self) -> List[ConnectedClient]:
        """Get all connected clients."""
        return list(self._clients.values())
    
    def get_connected_device_macs(self) -> List[str]:
        """Get list of all connected device MAC addresses."""
        return list(self._clients.keys())
    
    # =========================================================================
    # Bluetooth Device Tracking
    # =========================================================================
    
    def update_bt_devices(self, parent_mac: str, bt_device_macs: List[str]) -> None:
        """Update BT devices connected to a parent device.
        
        Args:
            parent_mac: MAC of the phone/tablet that has BT devices connected
            bt_device_macs: List of BT device MACs connected to this parent
        """
        client = self._clients.get(parent_mac)
        if not client:
            print(f"[WEBSOCKET_SERVICE] Cannot update BT devices - parent {parent_mac} not connected")
            return
        
        # Clear old BT mappings for this parent
        old_bt_devices = client.bt_devices.copy()
        for old_bt_mac in old_bt_devices:
            if self._bt_to_parent.get(old_bt_mac) == parent_mac:
                del self._bt_to_parent[old_bt_mac]
        
        # Update with new BT devices
        client.bt_devices = bt_device_macs
        for bt_mac in bt_device_macs:
            self._bt_to_parent[bt_mac] = parent_mac
            
            # Also update device registry for BT device
            if self._device_registry:
                self._device_registry.update_last_seen(bt_mac)
        
        print(f"[WEBSOCKET_SERVICE] Updated BT devices for {client.device_name}: {bt_device_macs}")
    
    def get_bt_parent(self, bt_mac: str) -> Optional[str]:
        """Get parent device MAC for a Bluetooth device.
        
        Args:
            bt_mac: Bluetooth device MAC
        
        Returns:
            Parent device MAC, or None if not found
        """
        return self._bt_to_parent.get(bt_mac)
    
    def get_bt_devices_for_parent(self, parent_mac: str) -> List[str]:
        """Get list of BT devices connected to a parent."""
        client = self._clients.get(parent_mac)
        return client.bt_devices if client else []
    
    # =========================================================================
    # Message Routing
    # =========================================================================
    
    def find_destination_for_bt_command(self, target_bt_mac: str) -> Optional[str]:
        """Find which connected client should receive a BT command.
        
        Args:
            target_bt_mac: Target Bluetooth device MAC
        
        Returns:
            MAC of the parent device that has this BT device connected,
            or None if no parent found
        """
        parent_mac = self._bt_to_parent.get(target_bt_mac)

        if parent_mac and parent_mac in self._clients:
            client = self._clients[parent_mac]
            print(f"[WEBSOCKET_SERVICE] Found destination for BT {target_bt_mac}: {client.device_name} ({parent_mac})")
            return parent_mac

        # Recover from process restarts or transient bt_update loss by consulting
        # the persisted registry parent_device field when the parent is connected.
        if self._device_registry:
            bt_device = self._device_registry.get_device(target_bt_mac)
            if bt_device:
                registry_parent_mac = bt_device.get('parent_device')
                if registry_parent_mac and registry_parent_mac in self._clients:
                    client = self._clients[registry_parent_mac]
                    self._bt_to_parent[target_bt_mac] = registry_parent_mac
                    if target_bt_mac not in client.bt_devices:
                        client.bt_devices.append(target_bt_mac)
                    print(
                        f"[WEBSOCKET_SERVICE] Recovered BT route for {target_bt_mac} from registry: "
                        f"{client.device_name} ({registry_parent_mac})"
                    )
                    return registry_parent_mac
        
        print(f"[WEBSOCKET_SERVICE] No connected parent found for BT device {target_bt_mac}")
        return None
    
    def emit_to_device(self, mac_address: str, event: str, data: dict) -> bool:
        """Emit event to a specific device by MAC address.
        
        Args:
            mac_address: Target device MAC
            event: Event name
            data: Event data
        
        Returns:
            True if sent, False if device not connected
        """
        if not self._socketio:
            print("[WEBSOCKET_SERVICE] ERROR: SocketIO not initialized")
            return False
        
        client = self._clients.get(mac_address)
        if not client:
            print(f"[WEBSOCKET_SERVICE] Cannot emit - device {mac_address} not connected")
            return False
        
        self._socketio.emit(event, data, to=client.socket_id)
        print(f"[WEBSOCKET_SERVICE] Emitted '{event}' to {client.device_name} ({mac_address})")
        return True
    
    def emit_task(self, destination_mac: str, task_data: dict) -> bool:
        """Send a task to a device.
        
        Args:
            destination_mac: Target device MAC
            task_data: Task payload
        
        Returns:
            True if sent successfully
        """
        return self.emit_to_device(destination_mac, 'task', task_data)
    
    def emit_error(self, destination_mac: str, error_code: str, message: str) -> bool:
        """Send error to a device.
        
        Args:
            destination_mac: Target device MAC
            error_code: Error code
            message: Error message
        
        Returns:
            True if sent successfully
        """
        return self.emit_to_device(destination_mac, 'error', {
            'code': error_code,
            'message': message,
            'timestamp': datetime.now().isoformat()
        })
    
    def broadcast(self, event: str, data: dict, exclude_mac: Optional[str] = None) -> int:
        """Broadcast event to all connected clients.
        
        Args:
            event: Event name
            data: Event data
            exclude_mac: Optional MAC to exclude from broadcast
        
        Returns:
            Number of clients that received the message
        """
        if not self._socketio:
            return 0
        
        count = 0
        for mac, client in self._clients.items():
            if mac != exclude_mac:
                self._socketio.emit(event, data, to=client.socket_id)
                count += 1
        
        return count
    
    # =========================================================================
    # Statistics
    # =========================================================================
    
    def get_stats(self) -> dict:
        """Get service statistics."""
        total_bt_devices = len(self._bt_to_parent)
        
        return {
            'connected_clients': len(self._clients),
            'total_bt_devices': total_bt_devices,
            'clients': [
                {
                    'mac': c.mac_address,
                    'name': c.device_name,
                    'bt_devices': c.bt_devices,
                    'connected_at': c.connected_at.isoformat()
                }
                for c in self._clients.values()
            ]
        }


# Singleton instance
websocket_service = WebSocketService()
