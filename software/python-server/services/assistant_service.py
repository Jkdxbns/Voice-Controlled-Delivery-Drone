"""Assistant service - handles two-pass LLM pipeline for categorization and task generation."""

import json
import re
from pathlib import Path
from typing import Dict, Optional, Tuple

from core.gemini_loader import GeminiLoader
from config import BASE_DIR
from services.audit_log import audit_event


class AssistantService:
    """Handles two-pass assistant pipeline: categorization -> task generation."""
    
    def __init__(self, device_registry):
        """Initialize assistant service with templates and dependencies.
        
        Args:
            device_registry: DeviceRegistry instance
        """
        self.gemini_loader = GeminiLoader()
        self.device_registry = device_registry
        
        # Load prompt templates
        self.templates_dir = BASE_DIR / "prompt_templates"
        self.task_schemas = self._load_json(self.templates_dir / "task_schemas.json")
        self.pass1_template = self._load_text(self.templates_dir / "pass1_categorization.txt")
        self.pass2_templates = self._load_json(self.templates_dir / "pass2_task_prompts.json")
        
        print("[ASSISTANT_SERVICE] Initialized with two-pass pipeline")
    
    def _load_json(self, path: Path) -> dict:
        """Load JSON file."""
        try:
            with path.open('r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"[ASSISTANT_SERVICE] Error loading {path}: {e}")
            return {}
    
    def _load_text(self, path: Path) -> str:
        """Load text file."""
        try:
            with path.open('r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            print(f"[ASSISTANT_SERVICE] Error loading {path}: {e}")
            return ""
    
    def handle_request(self, user_query: str, source_device_mac: str, lm_model: str = None) -> dict:
        """Main entry point - orchestrates two-pass flow.
        
        Args:
            user_query: User's natural language input
            source_device_mac: MAC address of requesting device
            lm_model: Optional LM model identifier
        
        Returns:
            Dictionary with result or streaming flag
        """
        try:
            print(f"\n[ASSISTANT_SERVICE] ===== NEW REQUEST =====")
            print(f"[ASSISTANT_SERVICE] User query: {user_query}")
            print(f"[ASSISTANT_SERVICE] Source MAC: {source_device_mac}")
            audit_event(
                "assistant_pipeline",
                "request_started",
                user_query=user_query,
                source_device_mac=source_device_mac,
                lm_model=lm_model or "gemini-2.5-flash-lite",
            )
            
            # Pass 1: Categorization
            pass1_result = self.pass1_categorize(user_query, lm_model)
            category = pass1_result['category']
            
            print(f"[ASSISTANT_SERVICE] Pass 1 result: category={category}, confidence={pass1_result['confidence']}")
            audit_event(
                "assistant_pipeline",
                "pass1_result",
                user_query=user_query,
                source_device_mac=source_device_mac,
                result=pass1_result,
            )
            
            # Route based on category
            if category == 'text-generation':
                return self.handle_text_generation(pass1_result, lm_model)
            elif category == 'robot-control':
                # Migration alias: deterministic arm routing is handled in /lm/query,
                # keep this path compatible for legacy callers.
                return self.handle_bt_control(pass1_result, source_device_mac, lm_model)
            elif category == 'bt-control':
                return self.handle_bt_control(pass1_result, source_device_mac, lm_model)
            elif category == 'device-message':
                return self.handle_device_message(pass1_result, source_device_mac, lm_model)
            elif category == 'system-alarm':
                return self.handle_system_alarm(pass1_result, source_device_mac, lm_model)
            elif category == 'system-calendar':
                return self.handle_system_calendar(pass1_result, source_device_mac, lm_model)
            elif category == 'system-call':
                return self.handle_system_call(pass1_result, source_device_mac, lm_model)
            elif category == 'file-transfer':
                return self.handle_file_transfer(pass1_result, source_device_mac, lm_model)
            else:
                return {
                    "status": "error",
                    "error": {
                        "code": "UNKNOWN_CATEGORY",
                        "message": f"Unknown category: {category}"
                    }
                }
        
        except Exception as e:
            print(f"[ASSISTANT_SERVICE] Error in handle_request: {e}")
            import traceback
            traceback.print_exc()
            return {
                "status": "error",
                "error": {
                    "code": "PROCESSING_ERROR",
                    "message": str(e)
                }
            }
    
    def pass1_categorize(self, user_query: str, lm_model: str = None) -> dict:
        """Execute Pass 1: Categorization.
        
        Args:
            user_query: User's input
            lm_model: Optional LM model identifier
        
        Returns:
            Dictionary with category, confidence, reasoning, user-data
        """
        print("[ASSISTANT_SERVICE] Executing Pass 1: Categorization")
        
        # Construct prompt
        prompt = self.pass1_template.replace("{user_query}", user_query)
        
        # Call Gemini
        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()
        
        print(f"[ASSISTANT_SERVICE] Pass 1 raw output: {raw_output}")
        audit_event(
            "assistant_pipeline",
            "pass1_raw_output",
            user_query=user_query,
            raw_output=raw_output,
            lm_model=lm_model or "gemini-2.5-flash-lite",
        )
        
        # Parse JSON (remove markdown if present)
        json_text = self._extract_json(raw_output)
        result = json.loads(json_text)
        
        # Validate required fields
        required_fields = ['category', 'confidence', 'reasoning', 'user-data']
        for field in required_fields:
            if field not in result:
                raise ValueError(f"Pass 1 output missing required field: {field}")
        
        return result
    
    def handle_text_generation(self, pass1_result: dict, lm_model: str = None) -> dict:
        """Handle text-generation category - return flag to use streaming.
        
        Args:
            pass1_result: Output from Pass 1
            lm_model: Optional LM model identifier
        
        Returns:
            Dictionary with streaming flag
        """
        print("[ASSISTANT_SERVICE] Handling text-generation (streaming mode)")
        return {
            "use_streaming": True,
            "user_query": pass1_result['user-data'],
            "lm_model": lm_model
        }
    
    def handle_bt_control(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle bt-control category - execute Pass 2 and construct JSON.
        
        Args:
            pass1_result: Output from Pass 1
            source_device_mac: MAC address of requesting device
            lm_model: Optional LM model identifier
        
        Returns:
            Complete bt-control JSON response
        """
        print("[ASSISTANT_SERVICE] Handling bt-control")
        
        user_data = pass1_result['user-data']
        
        # Get device list from registry
        device_list_str = self._format_device_list()
        
        # Get output format from task_schemas
        output_format = self.task_schemas['pass2_output_formats']['bt-control'].get('output-format', [])
        output_format_str = json.dumps(output_format) if output_format else "null"
        
        print(f"[ASSISTANT_SERVICE] Device list:\n{device_list_str}")
        print(f"[ASSISTANT_SERVICE] Output format: {output_format_str}")
        
        # Execute Pass 2 with output format from schemas
        command, target_device_name = self.pass2_bt_control(
            user_data,
            device_list_str,
            output_format_str,
            lm_model
        )
        
        # Look up target device once
        target_device = self._find_device_by_name(target_device_name)
        
        # Construct final JSON
        final_json = self._construct_bt_control_json(
            user_data,
            source_device_mac,
            target_device_name,
            target_device,
            command
        )
        
        # Check if cross-device routing is needed
        if target_device and not final_json.get('error'):
            from services.websocket_service import WebSocketService
            websocket_service = WebSocketService()
            
            target_bt_mac = target_device.get('mac_address')
            
            # Priority 1: Check WebSocket service's live BT-to-parent mapping
            # This is the most reliable as it reflects actual live connections
            parent_mac = websocket_service.get_bt_parent(target_bt_mac) if target_bt_mac else None
            if parent_mac:
                print(f"[ASSISTANT_SERVICE] Found live parent via WebSocket BT mapping: {parent_mac}")
            
            # Priority 2: Check parent_device field in device registry
            if not parent_mac:
                parent_mac = target_device.get('parent_device')
                if parent_mac:
                    print(f"[ASSISTANT_SERVICE] Using parent_device from registry: {parent_mac}")
            
            # Priority 3: Check if ip_address looks like a MAC address (Flutter BT device fallback)
            if not parent_mac:
                ip_addr = target_device.get('ip_address', '')
                if ip_addr and ':' in ip_addr and len(ip_addr) == 17:
                    parent_mac = ip_addr
                    print(f"[ASSISTANT_SERVICE] Using ip_address as parent MAC (fallback): {parent_mac}")
            
            # If parent device exists and is different from source, route via WebSocket
            if parent_mac and parent_mac.upper() != source_device_mac.upper():
                # Check if parent device is connected via WebSocket
                if not websocket_service.is_client_connected(parent_mac):
                    parent_device = self.device_registry.get_device(parent_mac)
                    parent_name = parent_device.get('device_name', parent_mac) if parent_device else parent_mac
                    print(f"[ASSISTANT_SERVICE] Parent device {parent_name} ({parent_mac}) is NOT connected via WebSocket")
                    return {
                        "status": "error",
                        "error": {
                            "code": "PARENT_DEVICE_OFFLINE",
                            "message": f"The device '{parent_name}' that has '{target_device_name}' connected via Bluetooth is not currently connected to the server. Please ensure the app is running on {parent_name}.",
                            "parent_device": parent_mac,
                            "parent_name": parent_name,
                            "target_device": target_device_name
                        }
                    }
                
                return self._route_bt_command_to_parent(
                    final_json, 
                    source_device_mac, 
                    parent_mac,
                    target_device_name,
                    command
                )
        
        return {
            "status": "success",
            "result": final_json
        }
    
    def handle_device_message(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle device-message category - send a message notification to another device.
        
        Args:
            pass1_result: Output from Pass 1
            source_device_mac: MAC address of requesting device
            lm_model: Optional LM model identifier
        
        Returns:
            Response indicating message routing status
        """
        print("[ASSISTANT_SERVICE] Handling device-message")
        
        user_data = pass1_result['user-data']
        
        # Get device list (android devices only for messaging)
        device_list_str = self._format_device_list_for_messaging()
        
        print(f"[ASSISTANT_SERVICE] Device list for messaging:\n{device_list_str}")
        
        # Execute Pass 2 to extract message and target
        message, target_device_name = self.pass2_device_message(user_data, device_list_str, lm_model)
        
        # Look up target device
        target_device = self._find_device_by_name(target_device_name)
        
        if not target_device:
            return {
                "status": "error",
                "error": {
                    "code": "DEVICE_NOT_FOUND",
                    "message": f"Device '{target_device_name}' not found in registry"
                }
            }
        
        target_mac = target_device.get('mac_address', '')
        
        # Get source device info for the "from" attribution
        source_device = self.device_registry.get_device(source_device_mac)
        source_name = source_device.get('custom_name') or source_device.get('device_name', 'Unknown') if source_device else 'Unknown'
        source_device_str = self._format_device_string(source_device, source_device_mac)
        target_device_str = self._format_device_string(target_device, target_mac)
        
        # Construct the message task JSON
        message_task = {
            "task": "device-message",
            "user-data": user_data,
            "processing-device": "server",
            "source-device": source_device_str,
            "target-device": target_device_str,
            "output": {
                "message": message,
                "from_device": source_name,
                "generated_output": message
            }
        }
        
        # Check if target is different from source (cross-device)
        if target_mac.upper() == source_device_mac.upper():
            return {
                "status": "error",
                "error": {
                    "code": "SAME_DEVICE",
                    "message": "Cannot send a message to yourself"
                }
            }
        
        # Check if target device is connected via WebSocket
        from services.websocket_service import WebSocketService
        websocket_service = WebSocketService()
        
        if not websocket_service.is_client_connected(target_mac):
            target_name = target_device.get('custom_name') or target_device.get('device_name', target_mac)
            return {
                "status": "error",
                "error": {
                    "code": "TARGET_DEVICE_OFFLINE",
                    "message": f"Device '{target_name}' is not currently connected to the server.",
                    "target_device": target_mac,
                    "target_name": target_name
                }
            }
        
        # Add routing info
        message_task['_routed_from'] = source_device_mac
        message_task['_routed_from_name'] = source_name
        
        print(f"[ASSISTANT_SERVICE] Sending message to {target_device_name}: '{message}'")
        print(f"[ASSISTANT_SERVICE] From: {source_name} ({source_device_mac})")
        
        # Emit message to target device
        target_name = target_device.get('custom_name') or target_device.get('device_name', target_mac)
        success = websocket_service.emit_task(target_mac, message_task)
        
        if success:
            return {
                "status": "sent",
                "message": f"Message sent to {target_name}",
                "sent_to": target_mac,
                "sent_to_name": target_name,
                "content": message
            }
        else:
            return {
                "status": "error",
                "error": {
                    "code": "SEND_FAILED",
                    "message": f"Failed to send message to {target_name}. Device may have disconnected."
                }
            }

    def handle_system_alarm(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle system-alarm category - route to requesting device."""
        print("[ASSISTANT_SERVICE] Handling system-alarm")

        user_data = pass1_result['user-data']
        hour, minute, label = self.pass2_system_alarm(user_data, lm_model)

        task = self._build_system_task(
            task_type='system-alarm',
            user_data=user_data,
            source_mac=source_device_mac,
            output={
                'hour': hour,
                'minute': minute,
                'label': label
            }
        )

        target_device = self.device_registry.get_device(source_device_mac)
        target_name = target_device.get('custom_name') or target_device.get('device_name', source_device_mac) if target_device else source_device_mac

        return self._route_task_to_device(
            target_mac=source_device_mac,
            target_name=target_name,
            task=task,
            routed_from_mac='server',
            routed_from_name='server',
            success_message='Alarm command sent'
        )

    def handle_system_calendar(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle system-calendar category - route to requesting device."""
        print("[ASSISTANT_SERVICE] Handling system-calendar")

        user_data = pass1_result['user-data']
        title, start_time, duration_min, location, notes = self.pass2_system_calendar(user_data, lm_model)

        task = self._build_system_task(
            task_type='system-calendar',
            user_data=user_data,
            source_mac=source_device_mac,
            output={
                'title': title,
                'start_time': start_time,
                'duration_min': duration_min,
                'location': location,
                'notes': notes
            }
        )

        target_device = self.device_registry.get_device(source_device_mac)
        target_name = target_device.get('custom_name') or target_device.get('device_name', source_device_mac) if target_device else source_device_mac

        return self._route_task_to_device(
            target_mac=source_device_mac,
            target_name=target_name,
            task=task,
            routed_from_mac='server',
            routed_from_name='server',
            success_message='Calendar command sent'
        )

    def handle_system_call(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle system-call category - route to requesting device."""
        print("[ASSISTANT_SERVICE] Handling system-call")

        user_data = pass1_result['user-data']
        phone_number, contact_name = self.pass2_system_call(user_data, lm_model)

        task = self._build_system_task(
            task_type='system-call',
            user_data=user_data,
            source_mac=source_device_mac,
            output={
                'phone_number': phone_number,
                'contact_name': contact_name
            }
        )

        target_device = self.device_registry.get_device(source_device_mac)
        target_name = target_device.get('custom_name') or target_device.get('device_name', source_device_mac) if target_device else source_device_mac

        return self._route_task_to_device(
            target_mac=source_device_mac,
            target_name=target_name,
            task=task,
            routed_from_mac='server',
            routed_from_name='server',
            success_message='Call command sent'
        )

    def handle_file_transfer(self, pass1_result: dict, source_device_mac: str, lm_model: str = None) -> dict:
        """Handle file-transfer category - route to source device."""
        print("[ASSISTANT_SERVICE] Handling file-transfer")

        user_data = pass1_result['user-data']
        device_list_str = self._format_device_list_for_messaging()

        action, file_query, source_device_name, target_device_name = self.pass2_file_transfer(
            user_data,
            device_list_str,
            lm_model
        )

        action = (action or 'copy').strip().lower()
        if action not in ['move', 'copy']:
            action = 'copy'

        if not file_query:
            return {
                "status": "error",
                "error": {
                    "code": "MISSING_FILE_QUERY",
                    "message": "File name or query could not be determined"
                }
            }

        source_device = self._find_device_by_name(source_device_name)
        target_device = self._find_device_by_name(target_device_name)

        if not source_device:
            return {
                "status": "error",
                "error": {
                    "code": "SOURCE_DEVICE_NOT_FOUND",
                    "message": f"Source device '{source_device_name}' not found in registry"
                }
            }

        if not target_device:
            return {
                "status": "error",
                "error": {
                    "code": "TARGET_DEVICE_NOT_FOUND",
                    "message": f"Target device '{target_device_name}' not found in registry"
                }
            }

        source_mac = source_device.get('mac_address', '')
        target_mac = target_device.get('mac_address', '')

        if not source_mac or not target_mac:
            return {
                "status": "error",
                "error": {
                    "code": "MISSING_DEVICE_MAC",
                    "message": "Source or target device MAC missing"
                }
            }

        if source_mac.upper() == target_mac.upper():
            return {
                "status": "error",
                "error": {
                    "code": "SAME_DEVICE",
                    "message": "Source and target devices are the same"
                }
            }

        from services.websocket_service import WebSocketService
        websocket_service = WebSocketService()

        if not websocket_service.is_client_connected(source_mac):
            return {
                "status": "error",
                "error": {
                    "code": "SOURCE_DEVICE_OFFLINE",
                    "message": f"Source device '{source_device_name}' is not connected"
                }
            }

        if not websocket_service.is_client_connected(target_mac):
            return {
                "status": "error",
                "error": {
                    "code": "TARGET_DEVICE_OFFLINE",
                    "message": f"Target device '{target_device_name}' is not connected"
                }
            }

        source_device_str = self._format_device_string(source_device, source_mac)
        target_device_str = self._format_device_string(target_device, target_mac)

        source_name = source_device.get('custom_name') or source_device.get('device_name', source_device_name)
        target_name = target_device.get('custom_name') or target_device.get('device_name', target_device_name)

        source_requester = self.device_registry.get_device(source_device_mac)
        requester_name = source_requester.get('custom_name') or source_requester.get('device_name', 'Unknown') if source_requester else 'Unknown'

        task = {
            "task": "file-transfer",
            "user-data": user_data,
            "processing-device": "server",
            "source-device": source_device_str,
            "target-device": target_device_str,
            "output": {
                "action": action,
                "file_query": file_query,
                "source_mac": source_mac,
                "target_mac": target_mac,
                "source_name": source_name,
                "target_name": target_name
            }
        }

        routed_from_mac = source_device_mac if source_device_mac.upper() != source_mac.upper() else 'server'
        routed_from_name = requester_name if routed_from_mac != 'server' else 'server'

        return self._route_task_to_device(
            target_mac=source_mac,
            target_name=source_name,
            task=task,
            routed_from_mac=routed_from_mac,
            routed_from_name=routed_from_name,
            success_message=f"File transfer started: {file_query} -> {target_device_name}"
        )
    
    def pass2_device_message(self, user_data: str, device_list: str, lm_model: str = None) -> Tuple[str, str]:
        """Execute Pass 2 for device-message to extract message and target.
        
        Args:
            user_data: User's original query
            device_list: Formatted device list string
            lm_model: Optional LM model identifier
        
        Returns:
            Tuple of (message, target_device_name)
        """
        print("[ASSISTANT_SERVICE] Executing Pass 2: Device Message")
        
        # Load prompt template
        template_config = self.pass2_templates['device-message']
        prompt_template = template_config['user_prompt_template']
        
        # Construct prompt
        prompt = prompt_template.format(
            user_data=user_data,
            device_list=device_list
        )
        
        # Generate response
        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()
        
        print(f"[ASSISTANT_SERVICE] Pass 2 message output:\n{raw_output}")
        
        # Parse output
        message = ""
        target_device = ""
        
        for line in raw_output.strip().split('\n'):
            line = line.strip()
            if line.startswith('MESSAGE:'):
                message = line.split('MESSAGE:', 1)[1].strip()
            elif line.startswith('TARGET_DEVICE:'):
                target_device = line.split('TARGET_DEVICE:', 1)[1].strip()
        
        print(f"[ASSISTANT_SERVICE] Extracted message: '{message}'")
        print(f"[ASSISTANT_SERVICE] Target device: {target_device}")
        
        return message, target_device

    def pass2_system_alarm(self, user_data: str, lm_model: str = None) -> Tuple[int, int, str]:
        """Execute Pass 2 for system-alarm."""
        print("[ASSISTANT_SERVICE] Executing Pass 2: System Alarm")

        template_config = self.pass2_templates['system-alarm']
        prompt_template = template_config['user_prompt_template']
        prompt = prompt_template.format(user_data=user_data)

        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()

        print(f"[ASSISTANT_SERVICE] Pass 2 alarm output:\n{raw_output}")

        hour = 0
        minute = 0
        label = ""

        for line in raw_output.split('\n'):
            line = line.strip()
            if line.startswith('HOUR:'):
                try:
                    hour = int(line.split('HOUR:', 1)[1].strip() or 0)
                except ValueError:
                    hour = 0
            elif line.startswith('MINUTE:'):
                try:
                    minute = int(line.split('MINUTE:', 1)[1].strip() or 0)
                except ValueError:
                    minute = 0
            elif line.startswith('LABEL:'):
                label = line.split('LABEL:', 1)[1].strip()

        return hour, minute, label

    def pass2_system_calendar(self, user_data: str, lm_model: str = None) -> Tuple[str, str, int, str, str]:
        """Execute Pass 2 for system-calendar."""
        print("[ASSISTANT_SERVICE] Executing Pass 2: System Calendar")

        template_config = self.pass2_templates['system-calendar']
        prompt_template = template_config['user_prompt_template']
        prompt = prompt_template.format(user_data=user_data)

        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()

        print(f"[ASSISTANT_SERVICE] Pass 2 calendar output:\n{raw_output}")

        title = "Event"
        start_time = ""
        duration_min = 60
        location = ""
        notes = ""

        for line in raw_output.split('\n'):
            line = line.strip()
            if line.startswith('TITLE:'):
                title = line.split('TITLE:', 1)[1].strip() or title
            elif line.startswith('START_TIME:'):
                start_time = line.split('START_TIME:', 1)[1].strip()
            elif line.startswith('DURATION_MIN:'):
                try:
                    duration_min = int(line.split('DURATION_MIN:', 1)[1].strip() or duration_min)
                except ValueError:
                    duration_min = duration_min
            elif line.startswith('LOCATION:'):
                location = line.split('LOCATION:', 1)[1].strip()
            elif line.startswith('NOTES:'):
                notes = line.split('NOTES:', 1)[1].strip()

        return title, start_time, duration_min, location, notes

    def pass2_system_call(self, user_data: str, lm_model: str = None) -> Tuple[str, str]:
        """Execute Pass 2 for system-call."""
        print("[ASSISTANT_SERVICE] Executing Pass 2: System Call")

        template_config = self.pass2_templates['system-call']
        prompt_template = template_config['user_prompt_template']
        prompt = prompt_template.format(user_data=user_data)

        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()

        print(f"[ASSISTANT_SERVICE] Pass 2 call output:\n{raw_output}")

        phone_number = ""
        contact_name = ""

        for line in raw_output.split('\n'):
            line = line.strip()
            if line.startswith('PHONE_NUMBER:'):
                phone_number = line.split('PHONE_NUMBER:', 1)[1].strip()
            elif line.startswith('CONTACT_NAME:'):
                contact_name = line.split('CONTACT_NAME:', 1)[1].strip()

        return phone_number, contact_name

    def pass2_file_transfer(self, user_data: str, device_list: str, lm_model: str = None) -> Tuple[str, str, str, str]:
        """Execute Pass 2 for file-transfer."""
        print("[ASSISTANT_SERVICE] Executing Pass 2: File Transfer")

        template_config = self.pass2_templates['file-transfer']
        prompt_template = template_config['user_prompt_template']
        prompt = prompt_template.format(user_data=user_data, device_list=device_list)

        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()

        print(f"[ASSISTANT_SERVICE] Pass 2 file-transfer output:\n{raw_output}")

        action = "copy"
        file_query = ""
        source_device = ""
        target_device = ""

        for line in raw_output.split('\n'):
            line = line.strip()
            if line.startswith('ACTION:'):
                action = line.split('ACTION:', 1)[1].strip() or action
            elif line.startswith('FILE_QUERY:'):
                file_query = line.split('FILE_QUERY:', 1)[1].strip()
            elif line.startswith('SOURCE_DEVICE:'):
                source_device = line.split('SOURCE_DEVICE:', 1)[1].strip()
            elif line.startswith('TARGET_DEVICE:'):
                target_device = line.split('TARGET_DEVICE:', 1)[1].strip()

        return action, file_query, source_device, target_device

    def _build_system_task(self, task_type: str, user_data: str, source_mac: str, output: dict) -> dict:
        source_device = self.device_registry.get_device(source_mac)
        source_device_str = self._format_device_string(source_device, source_mac)

        return {
            "task": task_type,
            "user-data": user_data,
            "processing-device": "server",
            "source-device": source_device_str,
            "target-device": source_device_str,
            "output": output
        }

    def _route_task_to_device(
        self,
        target_mac: str,
        target_name: str,
        task: dict,
        routed_from_mac: str,
        routed_from_name: str,
        success_message: str
    ) -> dict:
        from services.websocket_service import WebSocketService
        websocket_service = WebSocketService()

        if not websocket_service.is_client_connected(target_mac):
            target_device = self.device_registry.get_device(target_mac)
            target_name = target_device.get('custom_name') or target_device.get('device_name', target_mac) if target_device else target_mac
            return {
                "status": "error",
                "error": {
                    "code": "TARGET_DEVICE_OFFLINE",
                    "message": f"Device '{target_name}' is not currently connected to the server.",
                    "target_device": target_mac,
                    "target_name": target_name
                }
            }

        task['_routed_from'] = routed_from_mac
        task['_routed_from_name'] = routed_from_name

        success = websocket_service.emit_task(target_mac, task)
        if success:
            return {
                "status": "routed",
                "message": success_message,
                "target_device": target_name
            }

        return {
            "status": "error",
            "error": {
                "code": "SEND_FAILED",
                "message": "Failed to send task to device."
            }
        }
    
    def _format_device_list_for_messaging(self) -> str:
        """Format device list for messaging prompt (android devices only).
        
        Returns:
            Formatted string of android devices
        """
        devices = self.device_registry.get_all_devices()
        lines = []
        
        for device in devices:
            device_type = device.get('device_type', 'unknown')
            # Only include android devices (phones/tablets), not bluetooth peripherals
            if device_type == 'bluetooth':
                continue
                
            mac = device.get('mac_address', '')
            name = device.get('custom_name') or device.get('device_name', 'Unknown')
            status = device.get('status', 'unknown')
            
            lines.append(f"- {name}: {mac} [android, status: {status}]")
        
        return '\n'.join(lines) if lines else "No devices available"
    
    def _route_bt_command_to_parent(
        self, 
        task_json: dict, 
        source_mac: str, 
        parent_mac: str,
        target_device_name: str,
        command: str
    ) -> dict:
        """Route bt-control command to parent device via WebSocket.
        
        Args:
            task_json: The constructed bt-control task JSON
            source_mac: MAC of device that initiated the request
            parent_mac: MAC of device that has the BT device connected
            target_device_name: Name of the target BT device
            command: The command to send
        
        Returns:
            Response indicating routing status
        """
        from services.websocket_service import WebSocketService
        
        websocket_service = WebSocketService()
        
        # Get source device name for attribution
        source_device = self.device_registry.get_device(source_mac)
        source_name = source_device.get('device_name', 'Unknown') if source_device else 'Unknown'
        
        # Add routing info to task
        task_json['_routed_from'] = source_mac
        task_json['_routed_from_name'] = source_name
        
        print(f"[ASSISTANT_SERVICE] Cross-device routing: {source_name} -> {parent_mac}")
        print(f"[ASSISTANT_SERVICE] Target BT device: {target_device_name}")
        print(f"[ASSISTANT_SERVICE] Command: {command}")
        
        # Debug: Show connected WebSocket clients
        connected_macs = websocket_service.get_connected_device_macs()
        print(f"[ASSISTANT_SERVICE] Connected WebSocket clients: {connected_macs}")
        
        # Get parent device name
        parent_device = self.device_registry.get_device(parent_mac)
        parent_name = parent_device.get('device_name', parent_mac) if parent_device else parent_mac
        
        # Emit task to parent device (connectivity already verified by caller)
        success = websocket_service.emit_task(parent_mac, task_json)
        
        if success:
            return {
                "status": "routed",
                "message": f"Command routed to {parent_name} for {target_device_name}",
                "routed_to": parent_mac,
                "routed_to_name": parent_name,
                "target_device": target_device_name,
                "command": command
            }
        else:
            # This shouldn't happen if caller verified connectivity, but handle it anyway
            return {
                "status": "error",
                "error": {
                    "code": "ROUTING_FAILED",
                    "message": f"Failed to route command to {parent_name}. Device may have disconnected.",
                    "parent_device": parent_mac,
                    "parent_name": parent_name
                }
            }
    
    def pass2_bt_control(
        self,
        user_data: str,
        device_list: str,
        output_format_str: str,
        lm_model: str = None
    ) -> Tuple[str, str]:
        """Execute Pass 2 for bt-control.
        
        Args:
            user_data: User's original query
            device_list: Formatted device list string
            output_format_str: JSON string of output formats from schemas
            lm_model: Optional LM model identifier
        
        Returns:
            Tuple of (command, target_device_name)
        """
        print("[ASSISTANT_SERVICE] Executing Pass 2: BT Control")
        
        # Load prompt template
        template_config = self.pass2_templates['bt-control']
        prompt_template = template_config['user_prompt_template']
        
        # Construct prompt with actual output format
        prompt = prompt_template.format(
            user_data=user_data,
            device_list=device_list,
            output_format=output_format_str
        )
        
        # Generate command
        model = self.gemini_loader.get_model(lm_model or "gemini-2.5-flash-lite")
        response = model.generate_content(prompt)
        raw_output = response.text.strip()
        
        print(f"[ASSISTANT_SERVICE] Pass 2 output:\n{raw_output}")
        audit_event(
            "assistant_pipeline",
            "pass2_bt_raw_output",
            user_data=user_data,
            raw_output=raw_output,
            lm_model=lm_model or "gemini-2.5-flash-lite",
        )
        
        # Parse output
        command, target_device = self._parse_bt_command_output(raw_output)
        
        print(f"[ASSISTANT_SERVICE] Final command: {command}")
        print(f"[ASSISTANT_SERVICE] Target device: {target_device}")
        audit_event(
            "assistant_pipeline",
            "pass2_bt_command",
            command=command,
            target_device=target_device,
            user_data=user_data,
        )
        
        return command, target_device
    
    def _parse_bt_command_output(self, raw_output: str) -> Tuple[str, str]:
        """Parse command and target device from Pass 2 output.
        
        Args:
            raw_output: Raw output from Gemini
        
        Returns:
            Tuple of (command, target_device_name)
        """
        lines = raw_output.strip().split('\n')
        command = ""
        target_device = ""
        
        for line in lines:
            line = line.strip()
            if line.startswith('TARGET_DEVICE:'):
                target_device = line.split('TARGET_DEVICE:')[1].strip()
            elif line and not line.startswith('TARGET_DEVICE:'):
                if not command:  # First non-empty line is the command
                    command = line
        
        # Fallback: if no TARGET_DEVICE found, use entire output as command
        if not command:
            command = raw_output.strip()
        
        return command, target_device
    
    def _format_device_list(self) -> str:
        """Format device list for LLM prompt.
        
        Returns:
            Formatted string of devices
        """
        devices = self.device_registry.get_all_devices()
        lines = []
        
        for device in devices:
            mac = device.get('mac_address', '')
            name = device.get('custom_name') or device.get('device_name', 'Unknown')
            device_type = device.get('device_type', 'unknown')
            status = device.get('status', 'unknown')
            
            if device_type == 'bluetooth':
                lines.append(f"- {name}: {mac} [Bluetooth, status: {status}]")
            else:
                lines.append(f"- {name}: {mac} [status: {status}]")
        
        return '\n'.join(lines) if lines else "No devices available"
    
    def _construct_bt_control_json(
        self,
        user_data: str,
        source_mac: str,
        target_device_name: str,
        target_device: Optional[dict],
        command: str
    ) -> dict:
        """Construct final bt-control JSON response.
        
        Args:
            user_data: User's original query
            source_mac: Source device MAC
            target_device_name: Target device name from Gemini
            target_device: Target device object (already looked up, or None)
            command: Generated command
        
        Returns:
            Complete bt-control JSON
        """
        # Get source device info
        source_device = self.device_registry.get_device(source_mac)
        source_device_str = self._format_device_string(source_device, source_mac)
        
        # Use pre-looked-up device
        if not target_device:
            # Device not found - return error
            return {
                "task": "bt-control",
                "user-data": user_data,
                "processing-device": "server",
                "source-device": source_device_str,
                "target-device": f"{target_device_name} (NOT FOUND)",
                "parent-device": source_device_str,
                "output": {
                    "generated_output": f"ERROR:DEVICE_NOT_FOUND:{target_device_name}"
                },
                "error": {
                    "code": "DEVICE_NOT_FOUND",
                    "message": f"Device '{target_device_name}' not found in registry"
                }
            }
        
        target_mac = target_device.get('mac_address', '')
        target_device_str = self._format_device_string(target_device, target_mac)
        
        # Update target device's last_seen timestamp (mark as active)
        # This keeps Bluetooth devices showing as "online" when commands are sent
        if target_mac:
            self.device_registry.update_last_seen(target_mac)
            print(f"[ASSISTANT_SERVICE] Updated activity for target device: {target_mac}")
        
        # Get parent device (for Bluetooth devices)
        parent_mac = target_device.get('parent_device')
        if parent_mac:
            parent_device = self.device_registry.get_device(parent_mac)
            parent_device_str = self._format_device_string(parent_device, parent_mac)
        else:
            parent_device_str = target_device_str
        
        return {
            "task": "bt-control",
            "user-data": user_data,
            "processing-device": "server",
            "source-device": source_device_str,
            "target-device": target_device_str,
            "parent-device": parent_device_str,
            "output": {
                "generated_output": command
            }
        }
    
    def _find_device_by_name(self, device_name: str) -> Optional[dict]:
        """Find device in registry by name (case-insensitive).
        
        Args:
            device_name: Device name to search for
        
        Returns:
            Device dict or None
        """
        if not device_name:
            return None
        
        devices = self.device_registry.get_all_devices()
        device_name_lower = device_name.lower().strip()
        
        for device in devices:
            # Check custom_name first, then device_name
            custom_name = (device.get('custom_name') or '').lower().strip()
            auto_name = (device.get('device_name') or '').lower().strip()
            
            if device_name_lower == custom_name or device_name_lower == auto_name:
                return device
            
            # Also check if device_name is contained in the names
            if device_name_lower in custom_name or device_name_lower in auto_name:
                return device
        
        return None
    
    def _format_device_string(self, device: Optional[dict], mac: str) -> str:
        """Format device info as string for JSON response.
        
        Args:
            device: Device dict from registry
            mac: MAC address
        
        Returns:
            Formatted string: "device_name (MAC: XX:XX:XX:XX:XX:XX)"
        """
        if device:
            name = device.get('custom_name') or device.get('device_name', 'Unknown')
            return f"{name} (MAC: {mac})"
        else:
            return f"Unknown (MAC: {mac})"
    
    def _extract_json(self, text: str) -> str:
        """Extract JSON from text that may contain markdown code blocks.
        
        Args:
            text: Raw text that may contain JSON
        
        Returns:
            Clean JSON string
        """
        # Remove markdown code blocks
        text = re.sub(r'```json\s*', '', text)
        text = re.sub(r'```\s*', '', text)
        
        # Find JSON object
        json_match = re.search(r'\{.*\}', text, re.DOTALL)
        if json_match:
            json_str = json_match.group(0)
            
            # Fix double curly braces (Gemini sometimes returns {{ }} instead of { })
            # Replace {{ with { and }} with } but only at the start/end
            json_str = re.sub(r'^\{\{', '{', json_str)
            json_str = re.sub(r'\}\}$', '}', json_str)
            
            return json_str
        
        return text.strip()
