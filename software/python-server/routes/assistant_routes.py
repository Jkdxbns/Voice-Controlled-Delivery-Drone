"""Assistant routes - handles two-pass LLM pipeline requests."""

import re
import uuid

from flask import Blueprint, request, jsonify, Response, stream_with_context
from services.assistant_service import AssistantService
from services.lm_service import LMService
import models.device_model as registry_module
from services.websocket_service import WebSocketService
from services.arm_execution_service import arm_execution_service
from services.audit_log import audit_event

bp = Blueprint('assistant', __name__)

# Initialize services (lazy initialization for assistant_service)
assistant_service = None
lm_service = LMService()


# Gripper calibration from live sweep: lower angle = tighter close.
GRIP_CLOSE_CMD = "g 10"
GRIP_OPEN_CMD = "g 80"


def _to_bool(value, default=False):
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    text = str(value).strip().lower()
    if text in ("1", "true", "yes", "y", "on"):
        return True
    if text in ("0", "false", "no", "n", "off"):
        return False
    return default


def get_assistant_service():
    """Get or create assistant service instance (lazy initialization)."""
    global assistant_service
    if assistant_service is None:
        assistant_service = AssistantService(registry_module.device_registry)
    return assistant_service


def _route_arm_command_internal(
    *,
    command: str,
    source_mac: str,
    target_bt_mac: str,
    target_device_name: str,
    plan_id: str,
    step_id: str,
    command_id: str,
):
    """Route one direct arm command via WebSocket BT mapping.

    Returns: (success, payload, status_code)
    """
    registry = registry_module.device_registry

    # Resolve target BT MAC by explicit MAC first, then by Bluetooth device name.
    resolved_bt_mac = (target_bt_mac or '').strip()
    if not resolved_bt_mac and registry is not None:
        devices = registry.get_all_devices()
        wanted = target_device_name.lower()
        for device in devices:
            if device.get('device_type') != 'bluetooth':
                continue
            custom_name = (device.get('custom_name') or '').strip()
            auto_name = (device.get('device_name') or '').strip()
            name_candidates = [custom_name.lower(), auto_name.lower()]
            if wanted in name_candidates or any(wanted in n for n in name_candidates if n):
                resolved_bt_mac = (device.get('mac_address') or '').strip()
                break

    if not resolved_bt_mac:
        return False, {
            "status": "error",
            "error": {
                "code": "TARGET_BT_NOT_FOUND",
                "message": f"Could not resolve Bluetooth target '{target_device_name}'. Provide target_bt_mac explicitly.",
                "target_device_name": target_device_name,
            },
        }, 404

    websocket_service = WebSocketService()
    destination_mac = websocket_service.find_destination_for_bt_command(resolved_bt_mac)
    if not destination_mac:
        return False, {
            "status": "error",
            "error": {
                "code": "BT_DEVICE_NOT_CONNECTED",
                "message": f"No connected parent device found for BT device {resolved_bt_mac}",
                "target_bt_mac": resolved_bt_mac,
            },
        }, 409

    # Use registry name if available for consistency with existing task schema.
    bt_device_name = target_device_name
    if registry is not None:
        bt_device = registry.get_device(resolved_bt_mac)
        if bt_device:
            bt_device_name = bt_device.get('custom_name') or bt_device.get('device_name') or target_device_name

    source_name = source_mac
    if registry is not None:
        source_device = registry.get_device(source_mac)
        if source_device:
            source_name = source_device.get('custom_name') or source_device.get('device_name') or source_mac

    task_payload = {
        "task": "bt-control",
        "target-device": f"{bt_device_name} (MAC: {resolved_bt_mac})",
        "command": command,
        "plan_id": plan_id,
        "step_id": step_id,
        "command_id": command_id,
        "_routed_from": source_mac,
        "_routed_from_name": source_name,
    }

    if not websocket_service.emit_task(destination_mac, task_payload):
        return False, {
            "status": "error",
            "error": {
                "code": "ROUTING_FAILED",
                "message": f"Failed to route command to parent device {destination_mac}",
                "routed_to": destination_mac,
            },
        }, 500

    return True, {
        "status": "routed",
        "message": f"Command routed to {bt_device_name}",
        "command": command,
        "plan_id": plan_id,
        "step_id": step_id,
        "command_id": command_id,
        "target_bt_mac": resolved_bt_mac,
        "target_device_name": bt_device_name,
        "routed_to": destination_mac,
    }, 200


def _detect_arm_intent(user_query: str):
    """Map a natural language request to a supported deterministic arm intent."""
    q = (user_query or "").strip().lower()
    q = q.replace("_", " ")

    has_blue = "blue" in q
    has_object = any(token in q for token in ("box", "cube", "block"))
    has_pick = ("pick" in q) or ("pick up" in q) or ("grab" in q)
    has_handover = (
        "pass me" in q
        or "hand over" in q
        or "handover" in q
        or "place in my hand" in q
        or "give me" in q
    )
    has_return = ("place back" in q) or ("put back" in q) or ("return" in q)

    if has_blue and has_object and has_pick and has_return:
        return "pick_blue_box_and_return"
    if has_blue and has_object and (has_handover or (has_pick and "hand" in q)):
        return "handover_blue_box"
    if has_blue and has_object and has_pick:
        return "pick_blue_box"
    return None


def _build_plan_for_intent(intent: str, source_mac: str, target_device_name: str, plan_id: str):
    """Build a deterministic plan payload compatible with /arm/execute-plan."""
    common = {
        "source_device_mac": source_mac,
        "target_device_name": target_device_name,
        "plan_id": plan_id,
        "default_timeout_ms": 12000,
        "default_retries": 1,
        "default_post_done_delay_ms": 700,
    }

    if intent == "pick_blue_box":
        steps = [
            {"step_id": "s1", "command": "home", "timeout_ms": 10000},
            {"step_id": "s2", "command": "track_pick blue_cube", "timeout_ms": 45000},
            {"step_id": "s3", "command": "home", "timeout_ms": 12000},
        ]
    elif intent == "handover_blue_box":
        steps = [
            {"step_id": "s1", "command": "home", "timeout_ms": 10000},
            {"step_id": "s2", "command": "track_pick blue_cube", "timeout_ms": 45000},
            {"step_id": "s3", "command": "b 90", "timeout_ms": 10000, "post_done_delay_ms": 1000},
            {"step_id": "s4", "command": GRIP_OPEN_CMD, "timeout_ms": 9000, "post_done_delay_ms": 1200},
            {"step_id": "s5", "command": "home", "timeout_ms": 12000},
        ]
    elif intent == "pick_blue_box_and_return":
        steps = [
            {"step_id": "s1", "command": "home", "timeout_ms": 10000},
            {"step_id": "s2", "command": "track_pick blue_cube", "timeout_ms": 45000},
            {"step_id": "s3", "command": "home", "timeout_ms": 12000},
            {"step_id": "s4", "command": GRIP_OPEN_CMD, "timeout_ms": 9000, "post_done_delay_ms": 1200},
            {"step_id": "s5", "command": "home", "timeout_ms": 12000},
        ]
    else:
        return None

    payload = dict(common)
    payload["steps"] = steps
    audit_event(
        "arm_pipeline",
        "intent_plan_built",
        intent=intent,
        source_mac=source_mac,
        target_device_name=target_device_name,
        plan_id=plan_id,
        steps=steps,
    )
    return payload


def _execute_plan_payload(data: dict):
    """Execute plan payload and return (response_dict, status_code)."""
    source_mac = (data.get('source_device_mac') or '').strip()
    target_bt_mac = (data.get('target_bt_mac') or '').strip()
    target_device_name = (data.get('target_device_name') or 'robotic-arm').strip()
    plan_id = (data.get('plan_id') or '').strip() or f"plan-{uuid.uuid4().hex[:12]}"
    steps = data.get('steps') or []

    default_timeout_ms = int(data.get('default_timeout_ms', 8000))
    default_retries = int(data.get('default_retries', 0))
    default_post_done_delay_ms = int(data.get('default_post_done_delay_ms', 0))
    fallback_on_failure = _to_bool(data.get('fallback_on_failure', True), True)
    global_fallback_command = (data.get('global_fallback_command') or 'home').strip()

    print("\n" + "=" * 80)
    print("[ASSISTANT] POST /arm/execute-plan called")
    print("=" * 80)
    print(
        f"[DEBUG] plan_id={plan_id}, source={source_mac}, "
        f"target_bt_mac={target_bt_mac}, target_device_name={target_device_name}, steps={len(steps)}"
    )
    audit_event(
        "arm_pipeline",
        "plan_execution_started",
        plan_id=plan_id,
        source_mac=source_mac,
        target_bt_mac=target_bt_mac,
        target_device_name=target_device_name,
        steps=steps,
    )

    if not source_mac:
        return {
            "status": "error",
            "error": {
                "code": "MISSING_SOURCE_MAC",
                "message": "Missing source device MAC (body.source_device_mac or X-Device-MAC header)",
            },
        }, 400

    if not isinstance(steps, list) or not steps:
        return {
            "status": "error",
            "error": {
                "code": "INVALID_STEPS",
                "message": "'steps' must be a non-empty array",
            },
        }, 400

    step_results = []

    for idx, step in enumerate(steps, start=1):
        if not isinstance(step, dict):
            return {
                "status": "error",
                "error": {
                    "code": "INVALID_STEP",
                    "message": f"Step {idx} must be an object",
                },
            }, 400

        step_id = (step.get('step_id') or f's{idx}').strip()
        command = (step.get('command') or '').strip()
        if not command:
            return {
                "status": "error",
                "error": {
                    "code": "MISSING_STEP_COMMAND",
                    "message": f"Step {step_id} missing 'command'",
                },
            }, 400

        timeout_ms = int(step.get('timeout_ms', default_timeout_ms))
        retries = int(step.get('retries', default_retries))
        post_done_delay_ms = int(step.get('post_done_delay_ms', default_post_done_delay_ms))
        fallback_command = (step.get('fallback_command') or '').strip()

        attempt = 0
        step_ok = False
        last_wait = None
        last_error = None
        terminal_status = ''

        while attempt <= retries:
            attempt += 1
            command_id = (step.get('command_id') or '').strip()
            if command_id and attempt > 1:
                command_id = f"{command_id}-a{attempt}"
            if not command_id:
                command_id = f"{plan_id}-{step_id}-a{attempt}"

            print(
                f"[ASSISTANT] Dispatching step {step_id} attempt {attempt}/{retries + 1}: "
                f"command='{command}', command_id={command_id}"
            )
            audit_event(
                "arm_pipeline",
                "step_dispatch",
                plan_id=plan_id,
                step_id=step_id,
                command=command,
                command_id=command_id,
                attempt=attempt,
                retries=retries,
            )

            arm_execution_service.reset_tracking(
                command_id=command_id,
                plan_id=plan_id,
                step_id=step_id,
            )

            ok, route_payload, route_code = _route_arm_command_internal(
                command=command,
                source_mac=source_mac,
                target_bt_mac=target_bt_mac,
                target_device_name=target_device_name,
                plan_id=plan_id,
                step_id=step_id,
                command_id=command_id,
            )

            if not ok:
                last_error = {
                    "type": "route_error",
                    "payload": route_payload,
                    "status_code": route_code,
                }
                audit_event(
                    "arm_pipeline",
                    "step_route_error",
                    plan_id=plan_id,
                    step_id=step_id,
                    command=command,
                    command_id=command_id,
                    error=last_error,
                )
                if attempt <= retries:
                    continue
                break

            print(
                f"[ASSISTANT] Waiting for terminal ACK: command_id={command_id}, "
                f"plan_id={plan_id}, step_id={step_id}, timeout_ms={timeout_ms}"
            )
            wait_result = arm_execution_service.wait_for_terminal(
                command_id,
                timeout_ms / 1000.0,
                plan_id=plan_id,
                step_id=step_id,
            )
            last_wait = wait_result
            terminal_status = wait_result.get('status', '')
            audit_event(
                "arm_pipeline",
                "step_wait_result",
                plan_id=plan_id,
                step_id=step_id,
                command=command,
                command_id=command_id,
                wait_result=wait_result,
            )

            if terminal_status == 'done':
                step_ok = True
                if post_done_delay_ms > 0:
                    print(
                        f"[ASSISTANT] Step {step_id} done; waiting settle delay "
                        f"{post_done_delay_ms}ms before next step"
                    )
                    from time import sleep
                    sleep(post_done_delay_ms / 1000.0)
                break

            last_error = {
                "type": "execution_error",
                "status": terminal_status,
                "last": wait_result.get('last'),
            }
            if attempt <= retries:
                print(
                    f"[ASSISTANT] Step {step_id} attempt {attempt} ended with {terminal_status}; retrying"
                )

        step_result = {
            "step_id": step_id,
            "command": command,
            "ok": step_ok,
            "attempts": attempt,
            "terminal_status": terminal_status,
            "wait_result": last_wait,
            "error": last_error,
        }
        step_results.append(step_result)
        audit_event(
            "arm_pipeline",
            "step_result",
            plan_id=plan_id,
            step_result=step_result,
        )

        if not step_ok:
            print(f"[ASSISTANT] Step {step_id} failed after {attempt} attempt(s)")

            if fallback_on_failure:
                fb_cmd = fallback_command or global_fallback_command
                if fb_cmd:
                    fb_command_id = f"{plan_id}-{step_id}-fallback"
                    print(
                        f"[ASSISTANT] Executing fallback command '{fb_cmd}' for step {step_id} "
                        f"with command_id={fb_command_id}"
                    )
                    _route_arm_command_internal(
                        command=fb_cmd,
                        source_mac=source_mac,
                        target_bt_mac=target_bt_mac,
                        target_device_name=target_device_name,
                        plan_id=plan_id,
                        step_id=f"{step_id}-fallback",
                        command_id=fb_command_id,
                    )

            print("=" * 80 + "\n")
            audit_event(
                "arm_pipeline",
                "plan_execution_failed",
                plan_id=plan_id,
                failed_step=step_id,
                results=step_results,
            )
            return {
                "status": "error",
                "plan_id": plan_id,
                "failed_step": step_id,
                "results": step_results,
                "error": {
                    "code": "STEP_FAILED",
                    "message": f"Step {step_id} failed",
                },
            }, 500

    print(f"[ASSISTANT] Plan {plan_id} completed successfully")
    print("=" * 80 + "\n")
    audit_event(
        "arm_pipeline",
        "plan_execution_done",
        plan_id=plan_id,
        results=step_results,
    )
    return {
        "status": "done",
        "plan_id": plan_id,
        "results": step_results,
    }, 200


@bp.route('/lm/query', methods=['POST'])
def handle_assistant_request():
    """Main assistant endpoint - two-pass pipeline.
    
    Request body (JSON):
        {
            "user_query": str,
            "source_device_mac": str,
            "lm_model": str (optional)
        }
    
    Returns:
        For text-generation: SSE stream
        For bt-control: JSON response
    """
    try:
        data = request.get_json() or {}
        user_query = data.get('user_query')
        source_mac = data.get('source_device_mac')
        lm_model = data.get('lm_model')
        
        print("\n" + "="*80)
        print("[ASSISTANT] POST /lm/query called")
        print("="*80)
        print(f"[DEBUG] Request data:")
        print(f"  user_query: {user_query}")
        print(f"  source_device_mac: {source_mac}")
        print(f"  lm_model: {lm_model}")
        
        if not user_query:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_QUERY",
                    "message": "Missing 'user_query' field"
                }
            }), 400
        
        if not source_mac:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_SOURCE_MAC",
                    "message": "Missing 'source_device_mac' field"
                }
            }), 400

        arm_intent = _detect_arm_intent(user_query)
        if arm_intent:
            print(f"[ASSISTANT] /lm/query matched deterministic arm intent: {arm_intent}")
            audit_event(
                "arm_pipeline",
                "lm_query_arm_intent_redirect",
                user_query=user_query,
                source_mac=source_mac,
                lm_model=lm_model,
                intent=arm_intent,
            )
            plan_id = f"intent-{uuid.uuid4().hex[:12]}"
            plan_payload = _build_plan_for_intent(
                intent=arm_intent,
                source_mac=source_mac,
                target_device_name='robotic-arm',
                plan_id=plan_id,
            )
            result, status = _execute_plan_payload(plan_payload)
            response = {
                "query": user_query,
                "intent": arm_intent,
                "plan": {
                    "plan_id": plan_payload.get("plan_id"),
                    "steps": plan_payload.get("steps", []),
                },
            }
            response.update(result)
            print(f"[ASSISTANT] /lm/query arm intent result: {response.get('status')}")
            print("="*80 + "\n")
            return jsonify(response), status
        
        # Call assistant service
        print(f"[ASSISTANT] Calling handle_request()...")
        result = get_assistant_service().handle_request(user_query, source_mac, lm_model)
        
        # Check if text-generation (streaming)
        if result.get('use_streaming'):
            print(f"[ASSISTANT] Streaming response for text-generation")
            print("="*80 + "\n")
            # Return SSE stream
            return stream_text_generation(result['user_query'], lm_model)
        
        # bt-control or error: Return JSON
        if result.get('status') == 'error':
            print(f"[ASSISTANT] Error result: {result}")
            print("="*80 + "\n")
            return jsonify(result), 500
        
        print(f"[ASSISTANT] Success result: {result.get('status')}")
        print("="*80 + "\n")
        return jsonify(result), 200
    
    except Exception as e:
        print(f"[ASSISTANT_ROUTES] Error: {e}")
        import traceback
        traceback.print_exc()
        print("="*80 + "\n")
        
        return jsonify({
            "status": "error",
            "error": {
                "code": "INTERNAL_ERROR",
                "message": str(e)
            }
        }), 500


def stream_text_generation(user_query: str, lm_model: str = None):
    """Stream text generation response using SSE.
    
    Args:
        user_query: User's question
        lm_model: Optional LM model identifier
    
    Returns:
        SSE stream response
    """
    def generate():
        try:
            import json
            from services.catalog_service import CatalogService
            
            catalog_service = CatalogService()
            model_identifier = catalog_service.resolve_lm_model(lm_model)
            
            print(f"[STREAMING] Resolved Gemini model: {model_identifier}")
            print(f"[STREAMING] User query: {user_query}")
            
            # Status event
            yield f"event: status\ndata: {json.dumps({'status': 'generating'})}\n\n"
            
            # Generate streaming response
            response = lm_service.generate_content(
                prompt=user_query,
                model_identifier=model_identifier,
                stream=True
            )
            
            chunk_count = 0
            for chunk in response:
                if chunk.text:
                    chunk_count += 1
                    yield f"event: data\ndata: {json.dumps({'chunk': chunk.text})}\n\n"
            
            print(f"[STREAMING] Completed - sent {chunk_count} chunks")
            
            # Done event
            yield f"event: done\ndata: {json.dumps({'status': 'complete'})}\n\n"
        
        except Exception as e:
            print(f"[STREAMING] Error: {e}")
            yield f"event: error\ndata: {json.dumps({'error': str(e)})}\n\n"
    
    return Response(stream_with_context(generate()), mimetype='text/event-stream')


@bp.route('/arm/command', methods=['POST'])
def route_arm_command():
    """Direct arm command endpoint (bypasses LLM categorization).

    Request body (JSON):
        {
            "command": "g 40",                # required
            "source_device_mac": "...",       # optional (fallback: X-Device-MAC header)
            "target_bt_mac": "...",           # optional
            "target_device_name": "robotic-arm" # optional, default "robotic-arm"
        }

    Returns:
        JSON with routing status.
    """
    try:
        data = request.get_json() or {}
        command = (data.get('command') or '').strip()
        source_mac = (
            (data.get('source_device_mac') or '').strip()
            or (request.headers.get('X-Device-MAC') or '').strip()
        )
        target_bt_mac = (data.get('target_bt_mac') or '').strip()
        target_device_name = (data.get('target_device_name') or 'robotic-arm').strip()
        plan_id = (data.get('plan_id') or '').strip() or f"plan-{uuid.uuid4().hex[:12]}"
        step_id = (data.get('step_id') or '').strip() or 's1'
        command_id = (data.get('command_id') or '').strip() or f"cmd-{uuid.uuid4().hex[:12]}"

        print("\n" + "=" * 80)
        print("[ASSISTANT] POST /arm/command called")
        print("=" * 80)
        print(
            "[DEBUG] Request data: "
            f"command={command}, source={source_mac}, "
            f"target_bt_mac={target_bt_mac}, target_device_name={target_device_name}, "
            f"plan_id={plan_id}, step_id={step_id}, command_id={command_id}"
        )

        if not command:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_COMMAND",
                    "message": "Missing 'command' field"
                }
            }), 400

        if not source_mac:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_SOURCE_MAC",
                    "message": "Missing source device MAC (body.source_device_mac or X-Device-MAC header)"
                }
            }), 400

        ok, payload, status_code = _route_arm_command_internal(
            command=command,
            source_mac=source_mac,
            target_bt_mac=target_bt_mac,
            target_device_name=target_device_name,
            plan_id=plan_id,
            step_id=step_id,
            command_id=command_id,
        )

        if not ok:
            print(f"[ASSISTANT] Direct arm routing failed: {payload}")
            print("=" * 80 + "\n")
            return jsonify(payload), status_code

        print(
            f"[ASSISTANT] Routed direct arm command '{command}' "
            f"-> {payload.get('target_bt_mac')} via {payload.get('routed_to')}"
        )
        print("=" * 80 + "\n")
        return jsonify(payload), status_code

    except Exception as e:
        print(f"[ASSISTANT_ROUTES] /arm/command error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error",
            "error": {
                "code": "INTERNAL_ERROR",
                "message": str(e)
            }
        }), 500


@bp.route('/arm/execute-plan', methods=['POST'])
def execute_arm_plan():
    """Execute a multi-step arm plan with ACK wait, retries, and fallback.

    Request body (JSON):
        {
            "source_device_mac": ".."  # optional (fallback: X-Device-MAC header)
            "target_bt_mac": ".."      # optional
            "target_device_name": "robotic-arm"  # optional
            "plan_id": "plan-..."      # optional
            "steps": [
                {
                    "step_id": "s1",        # optional
                    "command": "home",      # required
                    "timeout_ms": 8000,      # optional
                    "retries": 1,            # optional
                    "fallback_command": "home"  # optional
                }
            ],
            "default_timeout_ms": 8000,      # optional
            "default_retries": 0,            # optional
            "fallback_on_failure": true,     # optional (default true)
            "global_fallback_command": "home" # optional
        }
    """
    try:
        data = request.get_json() or {}
        if not data.get('source_device_mac'):
            data['source_device_mac'] = (request.headers.get('X-Device-MAC') or '').strip()
        result, status = _execute_plan_payload(data)
        return jsonify(result), status
    except Exception as e:
        print(f"[ASSISTANT_ROUTES] /arm/execute-plan error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error",
            "error": {
                "code": "INTERNAL_ERROR",
                "message": str(e),
            },
        }), 500


@bp.route('/arm/intent', methods=['POST'])
def execute_arm_intent():
    """Map natural language arm request -> deterministic plan -> optional execute."""
    try:
        data = request.get_json() or {}
        user_query = (data.get('query') or data.get('text') or '').strip()
        source_mac = (
            (data.get('source_device_mac') or '').strip()
            or (request.headers.get('X-Device-MAC') or '').strip()
        )
        target_device_name = (data.get('target_device_name') or 'robotic-arm').strip()
        execute = _to_bool(data.get('execute', True), True)

        if not user_query:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "MISSING_QUERY",
                    "message": "Provide natural language in body.query or body.text",
                },
            }), 400

        intent = _detect_arm_intent(user_query)
        audit_event(
            "arm_pipeline",
            "intent_request",
            query=user_query,
            source_mac=source_mac,
            target_device_name=target_device_name,
            execute=execute,
            intent=intent,
        )
        if not intent:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "UNSUPPORTED_INTENT",
                    "message": "Supported intents: pick blue box, hand over/pass me blue box, pick blue box and place back",
                },
                "query": user_query,
            }), 400

        plan_id = (data.get('plan_id') or '').strip() or f"intent-{uuid.uuid4().hex[:12]}"
        plan_payload = _build_plan_for_intent(
            intent=intent,
            source_mac=source_mac,
            target_device_name=target_device_name,
            plan_id=plan_id,
        )

        if plan_payload is None:
            return jsonify({
                "status": "error",
                "error": {
                    "code": "INTENT_PLAN_BUILD_FAILED",
                    "message": f"No plan template for intent '{intent}'",
                },
                "query": user_query,
                "intent": intent,
            }), 500

        if not execute:
            audit_event(
                "arm_pipeline",
                "intent_plan_only_response",
                query=user_query,
                intent=intent,
                plan=plan_payload,
            )
            return jsonify({
                "status": "planned",
                "query": user_query,
                "intent": intent,
                "plan": plan_payload,
            }), 200

        result, status = _execute_plan_payload(plan_payload)
        response = {
            "query": user_query,
            "intent": intent,
            "plan": {
                "plan_id": plan_payload.get("plan_id"),
                "steps": plan_payload.get("steps", []),
            },
        }
        response.update(result)
        audit_event(
            "arm_pipeline",
            "intent_execution_response",
            query=user_query,
            intent=intent,
            response=response,
            status_code=status,
        )
        return jsonify(response), status
    except Exception as e:
        print(f"[ASSISTANT_ROUTES] /arm/intent error: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            "status": "error",
            "error": {
                "code": "INTERNAL_ERROR",
                "message": str(e),
            },
        }), 500
