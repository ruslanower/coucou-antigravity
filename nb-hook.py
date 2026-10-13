#!/usr/bin/env python3
"""
nb-hook.py — Dedicated Coucou Companion Bridge for Google Antigravity
Author: Ruslan Barbutsa
Repository: https://github.com/ruslanower/coucou-antigravity

Features:
- Real-time bidirectional notification synchronization between Antigravity and Coucou (macOS notch).
- Interactive question card duplication: Displays in both Coucou (with Mochi mascot) and Antigravity IDE modal.
- Automatic choice propagation: Clicking an option in Coucou automatically selects and submits that option in Antigravity.
- Zero-latency execution: Asynchronous workers and detached sessions ensure Antigravity never blocks or lags.
- Question card protection: Active question cards are never overwritten by background tool events.
"""

import sys
import json
import os
import socket
import subprocess

SOCKET_PATH = os.path.expanduser('~/Library/Application Support/NotchBuddy/nb.sock')
if not os.path.exists(SOCKET_PATH):
    if os.path.exists('/tmp/rango.sock'):
        SOCKET_PATH = '/tmp/rango.sock'
    elif os.path.exists('/tmp/tuktuk.sock'):
        SOCKET_PATH = '/tmp/tuktuk.sock'
WORKER_PID_FILE = '/tmp/rango_antigravity_worker.pid'
LAST_DECISION_FILE = '/tmp/rango_last_decision.json'


def is_worker_running():
    """Checks if a question card worker daemon is currently active."""
    if os.path.exists(WORKER_PID_FILE):
        try:
            with open(WORKER_PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            # Check if process is alive
            os.kill(pid, 0)
            return True
        except Exception:
            try:
                os.remove(WORKER_PID_FILE)
            except Exception:
                pass
    return False


def cleanup_antigravity_worker():
    """Terminates any existing background card worker."""
    if os.path.exists(WORKER_PID_FILE):
        try:
            with open(WORKER_PID_FILE, 'r') as f:
                pid = int(f.read().strip())
            os.kill(pid, 15)  # SIGTERM
        except Exception:
            pass
        try:
            os.remove(WORKER_PID_FILE)
        except Exception:
            pass


def spawn_antigravity_notch_worker(card_payload):
    """
    Spawns a detached background daemon that connects to Coucou's socket,
    holds the notch card open, and if an option is clicked in Coucou,
    automatically propagates that selection into Antigravity IDE via AppleScript.
    """
    cleanup_antigravity_worker()

    worker_code = """
import socket, json, os, sys, time, subprocess

sock_path = sys.argv[1]
raw_payload = sys.argv[2]
payload = json.loads(raw_payload)

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(120.0)
    s.connect(sock_path)
    s.sendall((json.dumps(payload) + "\\n").encode())
    resp = s.recv(4096)
    if resp:
        try:
            with open("/tmp/coucou_last_decision.json", "w") as f:
                f.write(resp.decode())
        except Exception:
            pass

        try:
            resp_obj = json.loads(resp.decode())
            if resp_obj.get("permissionDecision") == "answer":
                answers = resp_obj.get("answers", {})
                chosen_val = list(answers.values())[0] if answers else ""
                
                # Determine index of the selected option
                qs = payload.get("tool_input", {}).get("questions", [])
                opts = qs[0].get("options", []) if qs else []
                opt_labels = [o.get("label", "") if isinstance(o, dict) else str(o) for o in opts]
                
                idx = 0
                for i, lab in enumerate(opt_labels):
                    if lab == chosen_val or lab.strip() == chosen_val.strip():
                        idx = i
                        break

                key_num = str(idx + 1)
                osa = f'''
tell application "Antigravity" to activate
delay 0.2
tell application "System Events"
    keystroke "{key_num}"
    delay 0.1
    key code 36
end tell
'''
                res = subprocess.run(["osascript", "-e", osa], capture_output=True, text=True)
                try:
                    with open("/tmp/coucou_osa.log", "w") as f:
                        f.write(f"Key: {key_num}\\nStdout: {res.stdout}\\nStderr: {res.stderr}\\nReturnCode: {res.returncode}\\n")
                except Exception:
                    pass
        except Exception as err:
            with open("/tmp/coucou_osa_error.log", "w") as f:
                f.write(str(err))
except Exception as e:
    with open("/tmp/coucou_worker_error.log", "w") as f:
        f.write(str(e))
"""
    try:
        proc = subprocess.Popen(
            [sys.executable, '-c', worker_code, SOCKET_PATH, json.dumps(card_payload)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
            start_new_session=True
        )
        with open(WORKER_PID_FILE, 'w') as f:
            f.write(str(proc.pid))
    except Exception as e:
        try:
            with open('/tmp/coucou_spawn_error.log', 'w') as f:
                f.write(f"spawn error: {e}\n")
        except Exception:
            pass


def send_to_coucou_async(payload):
    """Fire-and-forget notification to Coucou (never blocks Antigravity)."""
    # If a question card is open, DO NOT overwrite it with tool events
    if is_worker_running():
        return

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.2)
        s.connect(SOCKET_PATH)
        s.sendall((json.dumps(payload) + '\n').encode())
        s.close()
    except Exception:
        pass


def normalize_antigravity_payload(raw_json):
    """Extracts standard event, tool, and session metadata from Antigravity."""
    data = {}
    try:
        data = json.loads(raw_json)
    except Exception:
        return {}

    tool_call = data.get('toolCall') or {}
    tool_name = tool_call.get('name') or data.get('tool_name') or data.get('tool') or ''
    tool_input = tool_call.get('args') or data.get('tool_input') or {}

    session_id = data.get('conversationId') or data.get('session_id') or 'antigravity'
    workspace_paths = data.get('workspacePaths') or []
    cwd = workspace_paths[0] if workspace_paths else (data.get('cwd') or os.getcwd())

    event = data.get('hook_event_name') or ''
    if not event:
        for arg in sys.argv[1:]:
            if arg in ('PreToolUse', 'PostToolUse', 'PreInvocation', 'PostInvocation', 'Stop'):
                event = arg
                break

    return {
        'hook_event_name': event,
        'tool_name': tool_name,
        'tool_input': tool_input,
        'session_id': session_id,
        'cwd': cwd,
        'coucou_agent': 'antigravity',
        'term_program': 'iTerm.app',
        'bundle_id': 'com.googlecode.iterm2'
    }


def main():
    raw_input = sys.stdin.buffer.read()
    if not raw_input:
        sys.stdout.write('{}\n')
        sys.stdout.flush()
        return

    payload = normalize_antigravity_payload(raw_input)
    event = payload.get('hook_event_name', '')
    tool_name = payload.get('tool_name', '')

    # 1. PostToolUse or Stop: Clean up active notch card workers
    if event in ('PostToolUse', 'Stop'):
        if event == 'Stop' or tool_name == 'ask_question':
            cleanup_antigravity_worker()
        send_to_coucou_async(payload)
        sys.stdout.write('{}\n')
        sys.stdout.flush()
        return

    # 2. PreToolUse handling
    if event == 'PreToolUse':
        # Interactive Questions (ask_question)
        if tool_name == 'ask_question':
            raw_qs = payload.get('tool_input', {}).get('questions', [])
            if isinstance(raw_qs, str):
                try:
                    raw_qs = json.loads(raw_qs)
                except Exception:
                    raw_qs = []
            elif not isinstance(raw_qs, list):
                raw_qs = [raw_qs] if raw_qs else []

            formatted_qs = []
            for q in raw_qs:
                if isinstance(q, str):
                    try:
                        q = json.loads(q)
                    except Exception:
                        continue
                if not isinstance(q, dict):
                    continue

                raw_opts = q.get('options', [])
                if isinstance(raw_opts, str):
                    try:
                        raw_opts = json.loads(raw_opts)
                    except Exception:
                        raw_opts = []

                opts = []
                for opt in raw_opts:
                    if isinstance(opt, str):
                        opts.append({'label': opt, 'description': ''})
                    elif isinstance(opt, dict):
                        opts.append({'label': str(opt.get('label') or opt.get('option') or opt), 'description': opt.get('description', '')})

                formatted_qs.append({
                    'question': q.get('question', ''),
                    'header': (q.get('question', '')[:12]),
                    'options': opts[:4],
                    'multiSelect': bool(q.get('is_multi_select') or q.get('multiSelect'))
                })

            if formatted_qs:
                q_card = {
                    'coucou_kind': 'ask_user_question',
                    'coucou_agent': 'antigravity',
                    'session_id': payload.get('session_id', 'antigravity'),
                    'cwd': payload.get('cwd', '') or os.getcwd(),
                    'term_program': 'iTerm.app',
                    'bundle_id': 'com.googlecode.iterm2',
                    'tool_name': 'AskUserQuestion',
                    'tool_input': {'questions': formatted_qs}
                }
                spawn_antigravity_notch_worker(q_card)

            sys.stdout.write('{"decision":"allow"}\n')
            sys.stdout.flush()
            return

        # General tools: telemetry to Coucou pill (only if no question card is active)
        send_to_coucou_async(payload)
        sys.stdout.write('{"decision":"ask"}\n')
        sys.stdout.flush()
        return

    # 3. PreInvocation / PostInvocation: notify Coucou without interrupting active workers
    send_to_coucou_async(payload)
    sys.stdout.write('{}\n')
    sys.stdout.flush()


if __name__ == '__main__':
    try:
        main()
    except Exception:
        sys.stdout.write('{}\n')
        sys.stdout.flush()
    sys.exit(0)