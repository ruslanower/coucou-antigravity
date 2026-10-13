#!/usr/bin/env python3
"""
nb-hook.py — Pure Antigravity Companion Bridge for CoucouAntigravity
Author: Ruslan Barbutsa
Repository: https://github.com/ruslanower/coucou-antigravity
"""

import sys
import json
import os
import socket

SOCKET_PATH = os.path.expanduser('~/Library/Application Support/NotchBuddy/nb.sock')


def send_to_notch(payload, timeout=0.5):
    """Sends a JSON message to CoucouAntigravity notch socket."""
    if not os.path.exists(SOCKET_PATH):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(SOCKET_PATH)
        s.sendall((json.dumps(payload) + '\n').encode('utf-8'))
        resp = s.recv(1024)
        s.close()
        return resp.decode('utf-8').strip() if resp else None
    except Exception:
        return None


def extract_payload(raw_json):
    """Parses stdin JSON payload from Antigravity."""
    try:
        data = json.loads(raw_json)
    except Exception:
        return {}

    tool_call = data.get('toolCall') or {}
    tool_name = tool_call.get('name') or data.get('tool_name') or data.get('tool') or ''
    tool_input = tool_call.get('args') or data.get('tool_input') or {}

    event = data.get('hook_event_name') or ''
    if not event:
        for arg in sys.argv[1:]:
            if arg in ('PreToolUse', 'PostToolUse', 'PreInvocation', 'PostInvocation', 'Stop'):
                event = arg
                break

    return {
        'event': event,
        'tool_name': tool_name,
        'tool_input': tool_input
    }


def main():
    raw_input = sys.stdin.buffer.read()
    if not raw_input:
        sys.stdout.write('{}\n')
        sys.stdout.flush()
        return

    data = extract_payload(raw_input)
    event = data.get('event', '')
    tool_name = data.get('tool_name', '')
    tool_input = data.get('tool_input', {})

    # 1. PreToolUse: Handle interactive questions & tools
    if event == 'PreToolUse':
        if tool_name == 'ask_question':
            questions = tool_input.get('questions', [])
            if questions:
                first_q = questions[0]
                q_text = first_q.get('question', '')
                raw_opts = first_q.get('options', [])
                options = []
                for opt in raw_opts:
                    if isinstance(opt, str):
                        options.append(opt)
                    elif isinstance(opt, dict) and 'label' in opt:
                        options.append(opt['label'])

                # Send question to Notch
                send_to_notch({
                    'type': 'ask_question',
                    'question': q_text,
                    'options': options
                })

            # Return "ask" immediately so Antigravity renders its IDE modal simultaneously
            sys.stdout.write('{"decision":"ask"}\n')
            sys.stdout.flush()
            return

        elif tool_name == 'run_command':
            cmd = tool_input.get('CommandLine') or tool_input.get('command') or ''
            cmd_preview = (cmd[:40] + '...') if len(cmd) > 40 else cmd
            send_to_notch({
                'type': 'status',
                'text': f"Команда: {cmd_preview}"
            })
            sys.stdout.write('{"decision":"ask"}\n')
            sys.stdout.flush()
            return

        sys.stdout.write('{"decision":"ask"}\n')
        sys.stdout.flush()
        return

    # 2. PostToolUse or Stop: Close notch card if open
    elif event in ('PostToolUse', 'Stop'):
        send_to_notch({'type': 'close'})
        sys.stdout.write('{}\n')
        sys.stdout.flush()
        return

    # 3. PreInvocation: Show subtle status
    elif event == 'PreInvocation':
        send_to_notch({
            'type': 'status',
            'text': "Antigravity думає..."
        })
        sys.stdout.write('{}\n')
        sys.stdout.flush()
        return

    # Default
    sys.stdout.write('{}\n')
    sys.stdout.flush()


if __name__ == '__main__':
    try:
        main()
    except Exception:
        sys.stdout.write('{}\n')
        sys.stdout.flush()
    sys.exit(0)