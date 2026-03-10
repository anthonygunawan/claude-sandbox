#!/bin/bash
CLAUDE_HOME="/home/claude"

# 1. Copy host .claude.json and pre-trust /workspace
if [[ -f /tmp/.claude.json.host ]]; then
    python3 -c "
import json
with open('/tmp/.claude.json.host') as f:
    data = json.load(f)
projects = data.get('projects', {})
if '/workspace' not in projects:
    projects['/workspace'] = {}
projects['/workspace']['hasTrustDialogAccepted'] = True
data['projects'] = projects
with open('$CLAUDE_HOME/.claude.json', 'w') as f:
    json.dump(data, f, indent=2)
"
fi

# 2. Set up SSH known_hosts
if [[ -f /host-ssh/known_hosts ]]; then
    mkdir -p "$CLAUDE_HOME/.ssh"
    cp /host-ssh/known_hosts "$CLAUDE_HOME/.ssh/known_hosts"
    chmod 700 "$CLAUDE_HOME/.ssh"
    chmod 600 "$CLAUDE_HOME/.ssh/known_hosts"
fi

# 3. Bridge host memory paths to container paths
if [[ -n "${HOST_HOME_PATH:-}" ]]; then
    HOST_GLOBAL_KEY=$(echo "$HOST_HOME_PATH" | tr '/' '-')
    HOST_GLOBAL_DIR="$CLAUDE_HOME/.claude/projects/$HOST_GLOBAL_KEY"

    if [[ -d "$HOST_GLOBAL_DIR" ]]; then
        ln -sfn -- "$HOST_GLOBAL_KEY" "$CLAUDE_HOME/.claude/projects/-home-claude"
    fi
fi

if [[ -n "${HOST_WORKSPACE_PATH:-}" ]]; then
    HOST_PROJECT_KEY=$(echo "$HOST_WORKSPACE_PATH" | tr '/' '-')
    HOST_PROJECT_DIR="$CLAUDE_HOME/.claude/projects/$HOST_PROJECT_KEY"

    if [[ -d "$HOST_PROJECT_DIR" ]]; then
        ln -sfn -- "$HOST_PROJECT_KEY" "$CLAUDE_HOME/.claude/projects/-workspace"
    fi
fi

# 4. Bridge host HOME path so absolute macOS paths in configs resolve
if [[ -n "${HOST_HOME_PATH:-}" && ! -e "$HOST_HOME_PATH" ]]; then
    sudo mkdir -p "$(dirname "$HOST_HOME_PATH")"
    sudo ln -sfn "$CLAUDE_HOME" "$HOST_HOME_PATH"
fi

# 5. Run Claude — supports both interactive and remote-control modes
#    CLAUDE_CMD is set by the shell script (default: "claude --dangerously-skip-permissions")
exec ${CLAUDE_CMD:-claude --dangerously-skip-permissions} "$@"
