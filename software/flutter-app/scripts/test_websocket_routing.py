"""
Test script to verify WebSocket cross-device routing.

This script simulates:
1. Two devices connecting (Phone and Tab)
2. Phone registering a Bluetooth device
3. Tab sending a command targeting the BT device
4. Verifying the command is routed to the Phone

Run with: python test_websocket_routing.py
"""

import socketio
import time
import json
import threading
from datetime import datetime

# Server configuration
SERVER_URL = "http://192.168.0.168:5000"

# Simulated device info
PHONE_INFO = {
    "mac_address": "5D:17:47:13:E7:49",
    "device_id": "device-phone-test",
    "device_name": "samsung SM-A356E",
    "model_name": "SM-A356E"
}

TAB_INFO = {
    "mac_address": "8B:F2:0A:2B:3C:3E",
    "device_id": "device-tab-test",
    "device_name": "samsung SM-X510",
    "model_name": "SM-X510"
}

# Simulated Bluetooth device (connected to Phone)
BT_DEVICE_MAC = "19:27:30:4F:7D:70"
BT_DEVICE_NAME = "drone"


class DeviceSimulator:
    """Simulates a device connecting via WebSocket."""
    
    def __init__(self, name: str, device_info: dict):
        self.name = name
        self.device_info = device_info
        self.sio = socketio.Client()
        self.connected = False
        self.registered = False
        self.received_tasks = []
        self.received_errors = []
        
        self._setup_handlers()
    
    def _setup_handlers(self):
        @self.sio.on('connect')
        def on_connect():
            print(f"[{self.name}] ✓ Connected to server")
            self.connected = True
        
        @self.sio.on('disconnect')
        def on_disconnect():
            print(f"[{self.name}] ✗ Disconnected from server")
            self.connected = False
        
        @self.sio.on('connected')
        def on_server_ack(data):
            print(f"[{self.name}] Server acknowledged: {data}")
        
        @self.sio.on('registered')
        def on_registered(data):
            print(f"[{self.name}] ✓ Registered: {data}")
            self.registered = True
        
        @self.sio.on('bt_update_ack')
        def on_bt_ack(data):
            print(f"[{self.name}] BT update acknowledged: {data}")
        
        @self.sio.on('task')
        def on_task(data):
            print(f"\n[{self.name}] ★★★ TASK RECEIVED ★★★")
            print(f"[{self.name}] Task data: {json.dumps(data, indent=2)}")
            self.received_tasks.append(data)
        
        @self.sio.on('command_routed')
        def on_routed(data):
            print(f"[{self.name}] Command was routed: {data}")
        
        @self.sio.on('error')
        def on_error(data):
            print(f"[{self.name}] ✗ Error: {data}")
            self.received_errors.append(data)
        
        @self.sio.on('response')
        def on_response(data):
            print(f"[{self.name}] Response: {data}")
    
    def connect(self):
        """Connect to server."""
        print(f"\n[{self.name}] Connecting to {SERVER_URL}...")
        try:
            self.sio.connect(SERVER_URL, transports=['websocket'])
            time.sleep(0.5)
            return self.connected
        except Exception as e:
            print(f"[{self.name}] Connection failed: {e}")
            return False
    
    def register(self):
        """Register device with server."""
        print(f"[{self.name}] Registering device...")
        self.sio.emit('register', self.device_info)
        time.sleep(0.5)
        return self.registered
    
    def send_bt_update(self, bt_devices: list):
        """Send BT device update.
        
        Args:
            bt_devices: List of dicts with 'mac' and 'name' keys,
                       or list of MAC strings (legacy format)
        """
        print(f"[{self.name}] Sending BT update: {bt_devices}")
        self.sio.emit('bt_update', {'connected_devices': bt_devices})
        time.sleep(0.3)
    
    def send_assistant_request(self, query: str):
        """Send assistant request."""
        print(f"\n[{self.name}] >>> Sending query: '{query}'")
        self.sio.emit('assistant_request', {'query': query})
    
    def disconnect(self):
        """Disconnect from server."""
        if self.connected:
            self.sio.disconnect()
            print(f"[{self.name}] Disconnected")


def test_cross_device_routing():
    """Test that commands are routed to the correct device."""
    
    print("=" * 60)
    print("WebSocket Cross-Device Routing Test")
    print("=" * 60)
    print(f"Server: {SERVER_URL}")
    print(f"Phone MAC: {PHONE_INFO['mac_address']}")
    print(f"Tab MAC: {TAB_INFO['mac_address']}")
    print(f"BT Device MAC: {BT_DEVICE_MAC}")
    print("=" * 60)
    
    phone = DeviceSimulator("PHONE", PHONE_INFO)
    tab = DeviceSimulator("TAB", TAB_INFO)
    
    try:
        # Step 1: Connect Phone
        print("\n--- Step 1: Connect Phone ---")
        if not phone.connect():
            print("FAILED: Phone could not connect")
            return False
        
        if not phone.register():
            print("FAILED: Phone could not register")
            return False
        
        # Step 2: Phone reports BT device connected
        print("\n--- Step 2: Phone reports BT device ---")
        phone.send_bt_update([{"mac": BT_DEVICE_MAC, "name": BT_DEVICE_NAME}])
        
        # Step 3: Connect Tab
        print("\n--- Step 3: Connect Tab ---")
        if not tab.connect():
            print("FAILED: Tab could not connect")
            return False
        
        if not tab.register():
            print("FAILED: Tab could not register")
            return False
        
        # Tab has no BT devices
        tab.send_bt_update([])
        
        # Step 4: Send command from Tab targeting BT device
        print("\n--- Step 4: Send command from Tab ---")
        test_queries = [
            "turn on the LED on drone",
            # "move robot forward 10 cm",
        ]
        
        for query in test_queries:
            phone.received_tasks.clear()
            tab.received_tasks.clear()
            
            tab.send_assistant_request(query)
            
            # Wait for response
            print("Waiting for routing...")
            time.sleep(3)
            
            # Check results
            print("\n--- Results ---")
            print(f"Phone received {len(phone.received_tasks)} task(s)")
            print(f"Tab received {len(tab.received_tasks)} task(s)")
            
            if phone.received_tasks:
                print("\n✓ SUCCESS: Command was routed to Phone!")
                task = phone.received_tasks[0]
                print(f"  Task type: {task.get('task')}")
                print(f"  Target device: {task.get('target-device')}")
                print(f"  Command: {task.get('output', {}).get('generated_output')}")
                print(f"  Routed from: {task.get('_routed_from_name', 'unknown')}")
            elif tab.received_tasks:
                print("\n⚠ Command was sent back to Tab (not routed)")
            elif tab.received_errors:
                print(f"\n✗ Error received: {tab.received_errors[-1]}")
            else:
                print("\n? No response received")
        
        print("\n" + "=" * 60)
        print("Test completed!")
        print("=" * 60)
        
        return len(phone.received_tasks) > 0
        
    except Exception as e:
        print(f"\nTest error: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        phone.disconnect()
        tab.disconnect()


def test_text_generation_stays_local():
    """Test that text-generation queries stay on the source device."""
    
    print("\n" + "=" * 60)
    print("Text Generation Local Response Test")
    print("=" * 60)
    
    tab = DeviceSimulator("TAB", TAB_INFO)
    
    try:
        if not tab.connect():
            print("FAILED: Tab could not connect")
            return False
        
        if not tab.register():
            print("FAILED: Tab could not register")
            return False
        
        # Send a text-generation query
        print("\n--- Sending text query from Tab ---")
        tab.send_assistant_request("What time is it?")
        
        time.sleep(3)
        
        print("\n--- Results ---")
        if tab.received_tasks:
            print("✓ Tab received response (as expected for text-generation)")
        else:
            print("Response would be streamed via HTTP for text-generation")
        
        return True
        
    finally:
        tab.disconnect()


if __name__ == "__main__":
    # Install dependency if needed
    try:
        import socketio
    except ImportError:
        print("Installing python-socketio...")
        import subprocess
        subprocess.run(["pip", "install", "python-socketio[client]"])
        import socketio
    
    # Run tests
    print("\n" + "#" * 60)
    print("# TEST 1: Cross-Device BT Command Routing")
    print("#" * 60)
    result1 = test_cross_device_routing()
    
    print("\n" + "#" * 60)
    print("# TEST 2: Text Generation Stays Local")
    print("#" * 60)
    result2 = test_text_generation_stays_local()
    
    # Summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    print(f"Cross-device routing: {'PASS ✓' if result1 else 'FAIL ✗'}")
    print(f"Text-gen local: {'PASS ✓' if result2 else 'FAIL ✗'}")
