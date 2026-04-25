"""
Test Cross-Device Bluetooth Command Routing

This script simulates:
1. Phone A (your Samsung) connects via WebSocket and registers its BT device (MLT-BT05)
2. Tablet (dummy device) connects and sends a command to the BT device
3. Server routes the command to Phone A, which should forward to BT device

Run with: python scripts/test_cross_device_bt.py
"""

import socketio
import time
import json
import threading

# Your actual device info from the registry
PHONE_MAC = "5D:17:47:13:E7:49"
PHONE_NAME = "samsung SM-A356E"
BT_DEVICE_MAC = "19:27:30:4F:7D:70"
BT_DEVICE_NAME = "MLT-BT05"

# Dummy tablet info
TABLET_MAC = "TA:BL:ET:99:88:77"
TABLET_NAME = "Test Tablet"

# Server URL
SERVER_URL = "http://localhost:5000"


class PhoneSimulator:
    """Simulates your actual phone with BT device connected."""
    
    def __init__(self):
        self.sio = socketio.Client()
        self.setup_handlers()
    
    def setup_handlers(self):
        @self.sio.on('connected')
        def on_connected(data):
            print(f"[PHONE] Server acknowledged: {data['message']}")
        
        @self.sio.on('registered')
        def on_registered(data):
            print(f"[PHONE] Registered: {data['message']}")
            # After registration, send BT device update
            self.send_bt_update()
        
        @self.sio.on('bt_update_ack')
        def on_bt_ack(data):
            print(f"[PHONE] BT devices registered: {data['bt_devices_count']} devices")
        
        @self.sio.on('task')
        def on_task(data):
            print(f"\n{'='*50}")
            print(f"[PHONE] 🎯 TASK RECEIVED FROM SERVER!")
            print(f"{'='*50}")
            print(json.dumps(data, indent=2))
            print(f"{'='*50}")
            
            # This is where the phone would send to BT device
            if data.get('task') == 'bt-control':
                cmd = data.get('command', '')
                target = data.get('target-device', '')
                print(f"\n[PHONE] → Would send '{cmd}' to BT device: {target}")
                print(f"[PHONE] → In real app, this goes to BluetoothConnection.write()")
        
        @self.sio.on('error')
        def on_error(data):
            print(f"[PHONE] Error: {data}")
    
    def connect(self):
        print(f"\n[PHONE] Connecting to server as {PHONE_NAME}...")
        self.sio.connect(SERVER_URL)
        
        # Register device
        self.sio.emit('register', {
            'mac_address': PHONE_MAC,
            'device_id': 'device-samsung-a35',
            'device_name': PHONE_NAME,
            'model_name': 'SM-A356E'
        })
    
    def send_bt_update(self):
        """Send BT device list to server."""
        print(f"[PHONE] Registering BT device: {BT_DEVICE_NAME} ({BT_DEVICE_MAC})")
        self.sio.emit('bt_update', {
            'connected_devices': [
                {'mac': BT_DEVICE_MAC, 'name': BT_DEVICE_NAME}
            ]
        })
    
    def disconnect(self):
        self.sio.disconnect()
        print("[PHONE] Disconnected")


class TabletSimulator:
    """Simulates a tablet sending commands to BT device."""
    
    def __init__(self):
        self.sio = socketio.Client()
        self.setup_handlers()
    
    def setup_handlers(self):
        @self.sio.on('connected')
        def on_connected(data):
            print(f"[TABLET] Server acknowledged: {data['message']}")
        
        @self.sio.on('registered')
        def on_registered(data):
            print(f"[TABLET] Registered: {data['message']}")
        
        @self.sio.on('command_routed')
        def on_routed(data):
            print(f"\n[TABLET] ✅ Command was routed!")
            print(f"  Target BT: {data.get('target_bt_device')}")
            print(f"  Routed to: {data.get('routed_to')}")
        
        @self.sio.on('task')
        def on_task(data):
            print(f"[TABLET] Task response: {data}")
        
        @self.sio.on('error')
        def on_error(data):
            print(f"[TABLET] ❌ Error: {data}")
        
        @self.sio.on('response')
        def on_response(data):
            print(f"[TABLET] Response: {data}")
    
    def connect(self):
        print(f"\n[TABLET] Connecting to server as {TABLET_NAME}...")
        self.sio.connect(SERVER_URL)
        
        # Register device
        self.sio.emit('register', {
            'mac_address': TABLET_MAC,
            'device_id': 'tablet-test-001',
            'device_name': TABLET_NAME,
            'model_name': 'Test Tablet Model'
        })
    
    def send_bt_command(self, command: str):
        """Send a direct BT command task to server."""
        print(f"\n[TABLET] 📤 Sending BT command: '{command}' to {BT_DEVICE_NAME}")
        
        # Emit a direct task instead of assistant_request
        # This bypasses AI processing and directly routes the command
        self.sio.emit('bt_command', {
            'target_bt_mac': BT_DEVICE_MAC,
            'command': command
        })
    
    def send_assistant_request(self, query: str):
        """Send an assistant request (goes through AI)."""
        print(f"\n[TABLET] 🤖 Sending assistant request: '{query}'")
        self.sio.emit('assistant_request', {
            'query': query
        })
    
    def disconnect(self):
        self.sio.disconnect()
        print("[TABLET] Disconnected")


def main():
    print("="*60)
    print("Cross-Device Bluetooth Command Routing Test")
    print("="*60)
    print(f"\nScenario:")
    print(f"  Phone: {PHONE_NAME} ({PHONE_MAC})")
    print(f"  BT Device: {BT_DEVICE_NAME} ({BT_DEVICE_MAC})")
    print(f"  Tablet: {TABLET_NAME} ({TABLET_MAC})")
    print(f"\nTablet will send 'led:on' command to BT device")
    print(f"Server should route it to Phone, which forwards to BT device")
    print("="*60)
    
    # Start phone first
    phone = PhoneSimulator()
    phone.connect()
    time.sleep(2)  # Wait for registration and BT update
    
    # Start tablet
    tablet = TabletSimulator()
    tablet.connect()
    time.sleep(1)  # Wait for registration
    
    # Send command from tablet to BT device
    print("\n" + "-"*60)
    print("SENDING COMMAND: 'led:on' to MLT-BT05")
    print("-"*60)
    
    tablet.send_bt_command('led:on')
    
    # Wait for routing
    time.sleep(3)
    
    # Cleanup
    print("\n" + "-"*60)
    print("Test complete. Cleaning up...")
    print("-"*60)
    
    tablet.disconnect()
    phone.disconnect()


if __name__ == "__main__":
    main()
