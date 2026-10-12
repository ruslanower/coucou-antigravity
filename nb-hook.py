#!/usr/bin/env python3
# nb-hook.py — Coucou hook relay for Claude Code and third-party agents (GitHub version)
# Reads JSON from stdin, forwards to Coucou via Unix socket, translates response.
import sys, json, os, socket

def normalize_event(name):
    mapping = {
        'BeforeTool': 'PreToolUse', 'BeforeToolSelection': 'PreToolUse',
        'AfterTool': 'PostToolUse', 'AfterModel': 'PostToolUse',
        'BeforeAgent': 'UserPromptSubmit', 'AfterAgent': 'Stop',
        'startup': 'SessionStart', 'exit': 'SessionEnd',
        'PreInvocation': 'UserPromptSubmit', 'PostInvocation': 'PostToolUse',
        'pre_tool_use': 'PreToolUse', 'post_tool_use': 'PostToolUse',
        'user_prompt_submit': 'UserPromptSubmit', 'session_start': 'SessionStart',
        'session_end': 'SessionEnd', 'stop': 'Stop',
        'sessionStart': 'SessionStart', 'userPromptSubmitted': 'UserPromptSubmit',
        'agentStop': 'Stop', 'notification': 'Notification',
        'preToolUse': 'PreToolUse', 'postToolUse': 'PostToolUse',
        'permissionRequest': 'PermissionRequest', 'sessionEnd': 'SessionEnd',
    }
    return mapping.get(name, name)

def normalize_tool_fields(payload):
    if 'tool_name' not in payload:
        # Copilot sends toolName directly; other agents nest in toolCall
        if payload.get('toolName'):
            payload['tool_name'] = payload['toolName']
        else:
            tool = payload.get('toolCall')
            if not isinstance(tool, dict):
                tool = {}
            name = tool.get('name') or payload.get('tool', '')
            if name:
                payload['tool_name'] = name
    if 'tool_input' not in payload:
        # Copilot sends toolArgs directly
        tool_args = payload.get('toolArgs')
        if isinstance(tool_args, dict):
            payload['tool_input'] = tool_args
        else:
            tool = payload.get('toolCall') or {}
            if isinstance(tool.get('args'), dict):
                flat = dict(tool['args'])
                for src, dst in [('CommandLine', 'command'), ('FilePath', 'file_path'),
                                 ('Path', 'path'), ('Url', 'url'), ('Query', 'query'), ('Pattern', 'pattern')]:
                    if src in flat:
                        flat[dst] = flat[src]
                payload['tool_input'] = flat
    if 'session_id' not in payload:
        for k in ['conversationId', 'conversation_id', 'sessionId', 'GEMINI_SESSION_ID']:
            if payload.get(k):
                payload['session_id'] = payload[k]
                break
        if 'session_id' not in payload:
            sid = os.environ.get('GEMINI_SESSION_ID', '')
            if sid:
                payload['session_id'] = sid
    # Copilot sends workdir for the current working directory
    if not payload.get('cwd') and payload.get('workdir'):
        payload['cwd'] = payload['workdir']


def cleanup_antigravity_worker():
    pid_file = "/tmp/coucou_antigravity_worker.pid"
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, 15)
        except Exception:
            pass
        try:
            os.remove(pid_file)
        except Exception:
            pass

def spawn_antigravity_notch_card(card_payload, socket_path):
    cleanup_antigravity_worker()
    import subprocess
    script = """
import socket, json, os, sys, time

socket_path = sys.argv[1]
raw_payload = sys.argv[2]
payload = json.loads(raw_payload)

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(120.0)
    s.connect(socket_path)
    s.sendall((json.dumps(payload) + "\\n").encode())
    resp = s.recv(4096)
    if resp:
        try:
            with open("/tmp/coucou_last_decision.json", "w") as f:
                f.write(resp.decode())
        except Exception:
            pass
except Exception as e:
    try:
        with open("/tmp/coucou_worker_error.log", "w") as f:
            f.write(str(e))
    except Exception:
        pass
"""
    try:
        proc = subprocess.Popen([
            sys.executable, "-c", script, socket_path, json.dumps(card_payload)
        ], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True, start_new_session=True)
        with open("/tmp/coucou_antigravity_worker.pid", "w") as f:
            f.write(str(proc.pid))
    except Exception:
        pass

def main():
    raw = b''
    payload = {}
    try:
        raw = sys.stdin.buffer.read()
        if not raw:
            if '--statusline' not in sys.argv[1:]:
                return
        else:
            payload = json.loads(raw)
    except Exception:
        if '--statusline' not in sys.argv[1:]:
            return

    socket_path = os.path.expanduser(
        '~/Library/Application Support/NotchBuddy/nb.sock'
    )

    # --statusline mode: relay rate_limits to Coucou, then delegate to saved previous
    if '--statusline' in sys.argv[1:]:
        relay = {
            'coucou_kind': 'statusline',
            'session_id': payload.get('session_id', ''),
            'rate_limits': payload.get('rate_limits', {}),
        }
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.3)
            s.connect(socket_path)
            s.sendall((json.dumps(relay) + '\n').encode())
            s.close()
        except Exception:
            pass
        prev_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'statusline-previous.json')
        if os.path.exists(prev_file):
            try:
                import subprocess
                with open(prev_file) as f:
                    prev = json.load(f)
                cmd = prev.get('command', '')
                if cmd:
                    result = subprocess.run(['/bin/sh', '-c', cmd], input=raw,
                                             capture_output=True, timeout=10)
                    if result.stdout:
                        sys.stdout.buffer.write(result.stdout)
                        sys.stdout.buffer.flush()
            except Exception:
                pass
        return

    # --ask mode: dedicated hook for AskUserQuestion via PreToolUse (Claude Code 2.1.85+)
    if '--ask' in sys.argv[1:]:
        tool = payload.get('tool_name', '')
        if tool != 'AskUserQuestion':
            return  # Not an AskUserQuestion invocation — exit cleanly (no output)
        payload['coucou_kind'] = 'ask_user_question'
        env = os.environ
        payload.setdefault('term_program', env.get('TERM_PROGRAM', ''))
        payload.setdefault('iterm_session_id', env.get('ITERM_SESSION_ID', ''))
        payload.setdefault('term_session_id', env.get('TERM_SESSION_ID', ''))
        payload.setdefault('bundle_id', env.get('__CFBundleIdentifier', ''))
        if 'cwd' not in payload or not payload['cwd']:
            paths = payload.get('workspacePaths') or payload.get('workspace_roots', [])
            if isinstance(paths, list) and paths:
                payload['cwd'] = paths[0]
            else:
                payload['cwd'] = os.getcwd()
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(125)
            s.connect(socket_path)
            s.sendall((json.dumps(payload) + '\n').encode())
            chunks = []
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    break
                chunks.append(chunk)
                if b'\n' in chunk:
                    break
            s.close()
            response = b''.join(chunks).decode().strip()
            if response:
                try:
                    resp_obj = json.loads(response)
                    decision = resp_obj.get('permissionDecision', '')
                except Exception:
                    decision = ''
                if decision == 'answer':
                    answers = resp_obj.get('answers', {})
                    questions = payload.get('tool_input', {}).get('questions', [])
                    out = {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'allow', 'updatedInput': {'questions': questions, 'answers': answers}}}
                    sys.stdout.write(json.dumps(out) + '\n')
                    sys.stdout.flush()
                    sys.exit(0)
                # 'ask' or unknown: fall through → no output → Claude Code asks in terminal
        except Exception:
            pass
        return

    # Parse --agent <name> and optional positional event from argv.
    # --agent tags the payload with coucou_agent so the app routes to the right pill.
    # The positional arg is a fallback event name for agents that do not set hook_event_name.
    args = sys.argv[1:]
    agent = ''
    arg_event = ''
    i = 0
    while i < len(args):
        if args[i] == '--agent' and i + 1 < len(args):
            agent = args[i + 1]
            i += 2
        else:
            if not arg_event:
                arg_event = args[i]
            i += 1
    if agent:
        payload.setdefault('coucou_agent', agent)
    # Claude Code sessions from the Claude desktop app (Code tab) report this entrypoint;
    # route them to the Claude Desktop pill instead of dropping them (no VS Code terminal).
    if not payload.get('coucou_agent') and os.environ.get('CLAUDE_CODE_ENTRYPOINT') == 'claude-desktop':
        payload['coucou_agent'] = 'claude-desktop'

    # Enrich with terminal context
    env = os.environ
    payload.setdefault('term_program', env.get('TERM_PROGRAM', 'iTerm.app') or 'iTerm.app')
    payload.setdefault('iterm_session_id', env.get('ITERM_SESSION_ID', ''))
    payload.setdefault('term_session_id', env.get('TERM_SESSION_ID', ''))
    payload.setdefault('bundle_id', env.get('__CFBundleIdentifier', 'com.googlecode.iterm2') or 'com.googlecode.iterm2')
    if 'cwd' not in payload or not payload['cwd']:
        paths = payload.get('workspacePaths') or payload.get('workspace_roots', [])
        if isinstance(paths, list) and paths:
            payload['cwd'] = paths[0]
        else:
            payload['cwd'] = os.getcwd()

    # Normalize event name and tool fields (Gemini CLI / Antigravity → canonical names)
    try:
        raw_event = payload.get('hook_event_name', '') or arg_event
        if raw_event:
            payload['hook_event_name'] = normalize_event(raw_event)
        normalize_tool_fields(payload)
    except Exception:
        pass

    event = payload.get('hook_event_name', '')
    # socket_path is already defined above

    if event == 'PermissionRequest':
        # Block and wait for Coucou's decision (Claude Code allows up to 120s)
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(118)
            s.connect(socket_path)
            s.sendall((json.dumps(payload) + '\n').encode())
            chunks = []
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    break
                chunks.append(chunk)
                if b'\n' in chunk:
                    break
            s.close()
            response = b''.join(chunks).decode().strip()
            if response:
                try:
                    resp_obj = json.loads(response)
                    decision = resp_obj.get('permissionDecision', '')
                except Exception:
                    decision = ''
                if agent == 'hermes':
                    hermes_choice = 'once' if decision == 'allow' else decision
                    if hermes_choice in ('once', 'always', 'deny'):
                        sys.stdout.write(json.dumps({'choice': hermes_choice}) + '\n')
                        sys.stdout.flush()
                    sys.exit(0)
                if decision in ('allow', 'always'):
                    # Copilot/Muse use {"permissionDecision":"allow"} directly
                    if agent in ('copilot', 'muse'):
                        out = {'permissionDecision': 'allow'}
                    elif decision == 'always' and agent != 'codex':
                        # Let Claude Code persist the rule via updatedPermissions
                        suggestions = payload.get('permission_suggestions', [])
                        out = {'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': {'behavior': 'allow', 'updatedPermissions': suggestions}}}
                    else:
                        # Claude Code / Codex plain allow
                        out = {'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': {'behavior': 'allow'}}}
                    sys.stdout.write(json.dumps(out) + '\n')
                    sys.stdout.flush()
                    sys.exit(0)
                elif decision == 'deny':
                    if agent in ('copilot', 'muse'):
                        out = {'permissionDecision': 'deny'}
                    else:
                        out = {'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': {'behavior': 'deny', 'message': 'Denied from Coucou'}}}
                    sys.stdout.write(json.dumps(out) + '\n')
                    sys.stdout.flush()
                    sys.exit(0)
                elif decision == 'answer':
                    # AskUserQuestion answered from the notch
                    answers = resp_obj.get('answers', {})
                    questions = payload.get('tool_input', {}).get('questions', [])
                    out = {'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': {'behavior': 'allow', 'updatedInput': {'questions': questions, 'answers': answers}}}}
                    sys.stdout.write(json.dumps(out) + '\n')
                    sys.stdout.flush()
                    sys.exit(0)
                # 'ask' or unknown: fall through → no output → agent re-asks
        except Exception:
            pass
        # App unreachable, timed out, or no explicit decision — print nothing
        # Copilot is fail-closed: must always output valid JSON so it re-asks rather than deny
        # Hermes: no output → json.loads raises in plugin → transport_fallback: builtin activates
        if agent == 'copilot':
            sys.stdout.write('{"permissionDecision":"ask"}\n')
            sys.stdout.flush()
        sys.exit(0)

    # All other events: fire-and-forget (0.3s timeout, never blocks)
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.3)
        s.connect(socket_path)
        s.sendall((json.dumps(payload) + '\n').encode())
        s.close()
    except Exception:
        pass  # Always exit cleanly — never block the agent

    # Antigravity handling: duplicate questions & permissions to notch card + IDE prompt
    if agent == 'antigravity':
        if event in ('PostToolUse', 'Stop'):
            cleanup_antigravity_worker()
            sys.stdout.write('{}\n')
            sys.stdout.flush()
            return

        if event == 'PreToolUse':
            tool_name = payload.get('tool_name', '')
            if tool_name == 'ask_question':
                raw_qs = payload.get('tool_input', {}).get('questions', [])
                formatted_qs = []
                for q in raw_qs:
                    opts = []
                    for opt in q.get('options', []):
                        if isinstance(opt, str):
                            opts.append({"label": opt, "description": ""})
                        elif isinstance(opt, dict):
                            opts.append(opt)
                    formatted_qs.append({
                        "question": q.get('question', ''),
                        "header": (q.get('question', '')[:12]),
                        "options": opts[:4],
                        "multiSelect": bool(q.get('is_multi_select') or q.get('multiSelect'))
                    })
                if formatted_qs:
                    q_card = {
                        "coucou_kind": "ask_user_question",
                        "coucou_agent": "antigravity",
                        "session_id": payload.get('session_id', 'antigravity'),
                        "cwd": payload.get('cwd', '') or os.getcwd(),
                        "term_program": "iTerm.app",
                        "bundle_id": "com.googlecode.iterm2",
                        "tool_name": "AskUserQuestion",
                        "tool_input": {"questions": formatted_qs}
                    }
                    try:
                        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                        s.settimeout(115.0)
                        s.connect(socket_path)
                        s.sendall((json.dumps(q_card) + "\n").encode())
                        chunks = []
                        while True:
                            chunk = s.recv(4096)
                            if not chunk:
                                break
                            chunks.append(chunk)
                            if b'\n' in chunk:
                                break
                        s.close()
                        resp_text = b''.join(chunks).decode().strip()
                        if resp_text:
                            resp_obj = json.loads(resp_text)
                            if resp_obj.get('permissionDecision') == 'answer':
                                answers = resp_obj.get('answers', {})
                                ans_list = [f"{k}: {v}" for k, v in answers.items()]
                                ans_str = "; ".join(ans_list)
                                out = {"decision": "deny", "reason": f"Відповідь користувача з чілки Coucou: {ans_str}"}
                                sys.stdout.write(json.dumps(out) + '\n')
                                sys.stdout.flush()
                                return
                    except Exception:
                        pass
            elif tool_name == 'run_command':
                cmd = payload.get('tool_input', {}).get('command') or payload.get('tool_input', {}).get('CommandLine', '')
                perm_card = {
                    "hook_event_name": "PermissionRequest",
                    "coucou_agent": "antigravity",
                    "session_id": payload.get('session_id', 'antigravity'),
                    "cwd": payload.get('cwd', '') or os.getcwd(),
                    "term_program": "iTerm.app",
                    "bundle_id": "com.googlecode.iterm2",
                    "tool_name": "run_command",
                    "command": cmd,
                    "tool_input": payload.get('tool_input', {})
                }
                try:
                    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    s.settimeout(115.0)
                    s.connect(socket_path)
                    s.sendall((json.dumps(perm_card) + "\n").encode())
                    chunks = []
                    while True:
                        chunk = s.recv(4096)
                        if not chunk:
                            break
                        chunks.append(chunk)
                        if b'\n' in chunk:
                            break
                    s.close()
                    resp_text = b''.join(chunks).decode().strip()
                    if resp_text:
                        resp_obj = json.loads(resp_text)
                        decision = resp_obj.get('permissionDecision', '')
                        if decision in ('allow', 'always'):
                            sys.stdout.write('{"decision":"allow"}\n')
                            sys.stdout.flush()
                            return
                        elif decision == 'deny':
                            sys.stdout.write('{"decision":"deny","reason":"Заблоковано з чілки Coucou"}\n')
                            sys.stdout.flush()
                            return
                except Exception:
                    pass

            sys.stdout.write('{"decision":"ask"}\n')
            sys.stdout.flush()
            return

    if agent in ('gemini', 'antigravity', 'muse', 'copilot'):
        sys.stdout.write('{}\n')
        sys.stdout.flush()

try:
    main()
except Exception:
    pass
sys.exit(0)