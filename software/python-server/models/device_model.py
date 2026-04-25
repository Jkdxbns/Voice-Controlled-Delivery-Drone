"""Device Registry Model - Data persistence for device tracking.

This model handles ONLY data storage and retrieval.
Business logic has been moved to services/device_service.py.
"""

import json
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from threading import Lock


class DeviceRegistry:
    """Manages device data persistence with JSON storage.
    
    Uses MAC address as PRIMARY KEY for device identification.
    Devices persist across app reinstalls and OS updates.
    """

    def __init__(self, storage_path: Path):
        """Initialize device registry.
        
        Args:
            storage_path: Path to JSON storage file.
        """
        self.storage_path = storage_path
        self.devices: Dict[str, dict] = {}
        self._lock = Lock()
        self._update_counter = 0
        self.load_from_disk()

    def register_device(
        self,
        device_id: str,
        device_name: str,
        model_name: str,
        ip_address: str,
        mac_address: Optional[str] = None,
        device_type: str = 'android',
        parent_device: Optional[str] = None,
    ) -> dict:
        """Add or update device in registry.
        
        Args:
            device_id: Device UUID (stored as field)
            device_name: Human-readable device name
            model_name: Device model identifier
            ip_address: Client IP address
            mac_address: Hardware MAC address (PRIMARY KEY - required)
            device_type: Type of device ('android', 'bluetooth', etc.)
            parent_device: MAC of parent device (for BT devices connected to a phone)
        
        Returns:
            Updated device record.
        
        Raises:
            ValueError: If MAC address is invalid or missing.
        """
        with self._lock:
            now = datetime.now().isoformat()
            
            # Validate and determine device key
            # Priority: MAC address > device_id
            device_key = None
            
            # Try to get valid MAC address
            if mac_address and mac_address != 'null':
                if ':' in mac_address and len(mac_address.split(':')) == 6:
                    if not mac_address.startswith(('192.168', '10.', '172.')):
                        device_key = mac_address
                        print(f"[DEVICE] Using MAC as key: {mac_address}")
            
            # Fallback to device_id if MAC is not available
            if not device_key:
                if device_id and device_id != 'unknown' and device_id != 'null':
                    device_key = device_id
                    print(f"[DEVICE] Using device_id as key (no valid MAC): {device_id}")
                    print(f"[DEVICE] Note: This device may duplicate on app reinstall")
                else:
                    # Last resort: create a temp key (will be problematic but allows registration)
                    import hashlib
                    temp_key = f"temp-{hashlib.md5(f'{device_name}{model_name}'.encode()).hexdigest()[:12]}"
                    device_key = temp_key
                    print(f"[DEVICE] No valid identifier - using temporary key: {temp_key}")
                    print(f"[DEVICE] WARNING: Fix MAC address extraction in mobile app!")
            
            # Check if device exists
            if device_key in self.devices:
                existing = self.devices[device_key]
                has_custom_name = existing.get('has_custom_name', False)
                
                # Update existing device
                device_record = {
                    'device_id': device_id,
                    'device_name': device_name,
                    'custom_name': existing.get('custom_name'),
                    'has_custom_name': has_custom_name,
                    'custom_name_updated_at': existing.get('custom_name_updated_at'),
                    'custom_name_updated_by': existing.get('custom_name_updated_by'),
                    'model_name': model_name,
                    'ip_address': ip_address,
                    'mac_address': mac_address or device_key,
                    'device_type': device_type,
                    'parent_device': parent_device or existing.get('parent_device'),
                    'status': 'online',
                    'first_seen': existing.get('first_seen', now),
                    'last_seen': now,
                }
            else:
                # New device
                device_record = {
                    'device_id': device_id,
                    'device_name': device_name,
                    'custom_name': None,
                    'has_custom_name': False,
                    'custom_name_updated_at': None,
                    'custom_name_updated_by': None,
                    'model_name': model_name,
                    'ip_address': ip_address,
                    'mac_address': mac_address or device_key,
                    'device_type': device_type,
                    'parent_device': parent_device,
                    'status': 'online',
                    'first_seen': now,
                    'last_seen': now,
                }
            
            self.devices[device_key] = device_record
            self.save_to_disk()
            
            return device_record

    def update_last_seen(self, mac_address: str):
        """Update device last_seen timestamp.
        
        Args:
            mac_address: Device hardware MAC address (primary key).
        """
        with self._lock:
            if mac_address in self.devices:
                self.devices[mac_address]['last_seen'] = datetime.now().isoformat()
                self.devices[mac_address]['status'] = 'online'
                
                # Save periodically to reduce disk I/O
                self._update_counter += 1
                if self._update_counter % 10 == 0:
                    self.save_to_disk()

    def auto_register_from_headers(self, headers: dict, ip_address: str) -> Optional[dict]:
        """Auto-register or update device from request headers.
        
        Args:
            headers: Request headers dictionary.
            ip_address: Client IP address.
            
        Returns:
            Device record if registered, None otherwise.
        """
        print(f"\n[AUTO-REGISTER] Extracting device info from headers...")
        print("="*80)
        print(f"  Headers: {headers}, ip_address: {ip_address}")
        print("="*80)
        
        device_id = headers.get('X-Device-Id')
        device_name = headers.get('X-Device-Name') or 'Unknown Device'
        model_name = headers.get('X-Device-Model') or 'Unknown Model'
        
        # Flask normalizes headers to title case, so check both variations
        mac_address = headers.get('X-Device-MAC') or headers.get('X-Device-Mac')
        
        print(f"[AUTO-REGISTER] Extracted values:")
        print(f"  X-Device-Id: {device_id}")
        print(f"  X-Device-Name: {device_name}")
        print(f"  X-Device-Model: {model_name}")
        print(f"  X-Device-MAC (or X-Device-Mac): {mac_address}")
        print(f"  ip_address: {ip_address}")
        
        if not mac_address or mac_address == 'null':
            print(f"[AUTO-REGISTER] No valid MAC address - cannot auto-register")
            print(f"  Checking device_id fallback: {device_id}")
            
            # Try with device_id as fallback
            if device_id and device_id != 'null' and device_id != 'unknown':
                print(f"[AUTO-REGISTER] Using device_id as identifier: {device_id}")
                mac_address = None  # Let register_device handle fallback
            else:
                print(f"[AUTO-REGISTER] ❌ No valid identifier available")
                return None
        
        if not device_id:
            device_id = f'device-{mac_address or "unknown"}'
            print(f"[AUTO-REGISTER] Generated device_id: {device_id}")
        
        try:
            print(f"[AUTO-REGISTER] Calling register_device()...")
            device = self.register_device(
                device_id=device_id,
                device_name=device_name,
                model_name=model_name,
                ip_address=ip_address,
                mac_address=mac_address
            )
            print(f"[AUTO-REGISTER] ✅ Registration successful")
            return device
        except ValueError as e:
            print(f"[AUTO-REGISTER] ❌ Registration failed: {e}")
            return None

    def update_device_statuses(self):
        """Update status to offline for devices not seen recently.
        
        Devices are marked offline after 2 minutes of inactivity.
        Devices are NEVER automatically removed.
        """
        with self._lock:
            now = datetime.now()
            offline_threshold = timedelta(minutes=2)
            
            for mac_address, device in self.devices.items():
                last_seen_str = device.get('last_seen')
                if not last_seen_str:
                    continue
                
                try:
                    last_seen = datetime.fromisoformat(last_seen_str)
                    time_since_seen = now - last_seen
                    
                    if time_since_seen > offline_threshold:
                        if device['status'] == 'online':
                            device['status'] = 'offline'
                            self.save_to_disk()
                
                except ValueError:
                    pass

    def get_all_devices(self) -> List[dict]:
        """Get all registered devices sorted by last_seen (newest first).
        
        Returns:
            List of device records.
        """
        with self._lock:
            devices_list = list(self.devices.values())
            devices_list.sort(key=lambda d: d.get('last_seen', ''), reverse=True)
            return devices_list

    def get_device(self, identifier: str) -> Optional[dict]:
        """Get device by MAC address or device_id.
        
        Args:
            identifier: Either MAC address (primary key) or device_id.
            
        Returns:
            Device record or None if not found.
        """
        with self._lock:
            # Try MAC address first
            if identifier in self.devices:
                return self.devices[identifier]
            
            # Fallback: search by device_id
            for mac, device in self.devices.items():
                if device.get('device_id') == identifier:
                    return device
            
            return None
    
    def update_device_custom_name(
        self,
        identifier: str,
        custom_name: str,
        updated_by_device_id: str
    ) -> Optional[dict]:
        """Update custom name for a device.
        
        Args:
            identifier: MAC address or device_id.
            custom_name: New custom name.
            updated_by_device_id: Device ID that initiated the change.
            
        Returns:
            Updated device record or None if device not found.
        """
        with self._lock:
            device_key = None
            device = None
            
            # Find device
            if identifier in self.devices:
                device_key = identifier
                device = self.devices[identifier]
            else:
                for mac, dev in self.devices.items():
                    if dev.get('device_id') == identifier:
                        device_key = mac
                        device = dev
                        break
            
            if not device:
                return None
            
            now = datetime.now().isoformat()
            
            # Update custom name fields
            device['custom_name'] = custom_name
            device['has_custom_name'] = True
            device['custom_name_updated_at'] = now
            device['custom_name_updated_by'] = updated_by_device_id
            
            self.save_to_disk()
            
            return device
    
    def clear_device_custom_name(self, identifier: str) -> Optional[dict]:
        """Clear custom name for a device (revert to auto-detected name).
        
        Args:
            identifier: MAC address or device_id.
            
        Returns:
            Updated device record or None if device not found.
        """
        with self._lock:
            device_key = None
            device = None
            
            # Find device
            if identifier in self.devices:
                device_key = identifier
                device = self.devices[identifier]
            else:
                for mac, dev in self.devices.items():
                    if dev.get('device_id') == identifier:
                        device_key = mac
                        device = dev
                        break
            
            if not device:
                return None
            
            # Clear custom name fields
            device['custom_name'] = None
            device['has_custom_name'] = False
            device['custom_name_updated_at'] = None
            device['custom_name_updated_by'] = None
            
            self.save_to_disk()
            
            return device

    def update_last_seen(self, identifier: str) -> bool:
        """Update device's last_seen timestamp and mark as online.
        
        Args:
            identifier: MAC address or device_id
        
        Returns:
            True if device was found and updated, False otherwise
        """
        with self._lock:
            device = None
            
            # Try MAC address first (fastest lookup)
            if identifier in self.devices:
                device = self.devices[identifier]
            else:
                # Try device_id lookup
                for dev in self.devices.values():
                    if dev.get('device_id') == identifier:
                        device = dev
                        break
            
            if not device:
                print(f"[DEVICE] Cannot update last_seen: device {identifier} not found")
                return False
            
            # Update timestamp and status
            device['last_seen'] = datetime.now().isoformat()
            device['status'] = 'online'
            
            # Save to disk (throttled to avoid excessive writes)
            self._update_counter += 1
            if self._update_counter % 5 == 0:  # Save every 5th update
                self.save_to_disk()
            
            return True

    def save_to_disk(self):
        """Persist registry to JSON file."""
        try:
            data = {
                'devices': self.devices,
                'last_updated': datetime.now().isoformat()
            }
            with self.storage_path.open('w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"[DEVICE] Failed to save registry: {e}")

    def load_from_disk(self):
        """Load registry from JSON file."""
        if not self.storage_path.exists():
            return
        
        try:
            with self.storage_path.open('r', encoding='utf-8') as f:
                data = json.load(f)
                self.devices = data.get('devices', {})
        except Exception as e:
            print(f"[DEVICE] Failed to load registry: {e}")
            self.devices = {}

    def get_stats(self) -> dict:
        """Get registry statistics.
        
        Returns:
            Dictionary with total, online, and offline device counts.
        """
        with self._lock:
            total = len(self.devices)
            online = sum(1 for d in self.devices.values() if d.get('status') == 'online')
            offline = total - online
            
            return {
                'total_devices': total,
                'online_devices': online,
                'offline_devices': offline
            }


# Global device registry instance (initialized in main.py)
device_registry: Optional[DeviceRegistry] = None
