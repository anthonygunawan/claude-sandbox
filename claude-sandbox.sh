#!/bin/bash
# claude-sandbox - Run Claude Code safely in a Docker container
#
# Mounts only the target project. Your Claude settings, memory, git config,
# and Bitbucket credentials carry over. SSH uses agent forwarding from host
# (passphrase handled by macOS Passwords app). Package caches persist via volumes.

set -euo pipefail

IMAGE_NAME="claude-sandbox"
WORKSPACE="$(pwd)"
CLAUDE_HOME="/home/claude"
CLAUDE_CMD="claude --dangerously-skip-permissions"
CLAUDE_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--workspace)
            [[ -z "${2:-}" ]] && echo "Error: -w requires a path" && exit 1
            WORKSPACE="$2"
            shift 2
            ;;
        -p)
            [[ -z "${2:-}" ]] && echo "Error: -p requires a task string" && exit 1
            CLAUDE_ARGS+=("-p" "$2")
            shift 2
            ;;
        --remote)
            CLAUDE_CMD="claude remote-control --permission-mode bypassPermissions"
            shift
            ;;
        --help|-h)
            echo "Usage: claude-sandbox [OPTIONS] [CLAUDE_ARGS...]"
            echo ""
            echo "Options:"
            echo "  -w, --workspace   Mount specific directory (default: cwd)"
            echo "  -p 'task'         Run a one-shot task non-interactively"
            echo "  --remote          Start remote control (control from claude.ai on phone)"
            echo "  -h, --help        Show this help"
            echo ""
            echo "Examples:"
            echo "  claude-sandbox                          # interactive in cwd"
            echo "  claude-sandbox -p 'fix all lint errors' # one-shot task"
            echo "  claude-sandbox --remote                 # control from phone"
            echo "  claude-sandbox -w ~/projects/myapp      # specific project"
            exit 0
            ;;
        *)
            if [[ -d "$1" ]]; then
                WORKSPACE="$1"
            else
                CLAUDE_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

WORKSPACE="$(cd "$WORKSPACE" && pwd)"

# Auto-build if image doesn't exist
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Image '$IMAGE_NAME' not found. Building..."
    docker build -t "$IMAGE_NAME" "$(dirname "$0")"
fi

MOUNTS=(
    -v "$WORKSPACE:/workspace"
    -v "$HOME/.claude:$CLAUDE_HOME/.claude"
    -v "$HOME/.claude.json:/tmp/.claude.json.host:ro"
    -v claude-npm-cache:$CLAUDE_HOME/.npm
    -v claude-pip-cache:$CLAUDE_HOME/.cache/pip
)

# Maven/Gradle from host — needed for publishToMavenLocal artifacts (shared-java-lib)
[[ -d "$HOME/.m2" ]] && MOUNTS+=(-v "$HOME/.m2:$CLAUDE_HOME/.m2")
[[ -d "$HOME/.gradle" ]] && MOUNTS+=(-v "$HOME/.gradle:$CLAUDE_HOME/.gradle")

# GCP Application Default Credentials — for Artifact Registry, etc.
[[ -d "$HOME/.config/gcloud" ]] && MOUNTS+=(-v "$HOME/.config/gcloud:$CLAUDE_HOME/.config/gcloud:ro")

# SSH agent forwarding — private key stays on host, passphrase via macOS Passwords app
MOUNTS+=(-v /run/host-services/ssh-auth.sock:/ssh-auth.sock)

# known_hosts for host verification (entrypoint copies it to ~/.ssh/)
[[ -d "$HOME/.ssh" ]] && MOUNTS+=(-v "$HOME/.ssh:/host-ssh:ro")

# Git identity
[[ -f "$HOME/.gitconfig" ]] && MOUNTS+=(-v "$HOME/.gitconfig:$CLAUDE_HOME/.gitconfig:ro")

ENV_VARS=(
    -e HOST_WORKSPACE_PATH="$WORKSPACE"
    -e HOST_HOME_PATH="$HOME"
    -e SSH_AUTH_SOCK=/ssh-auth.sock
    -e CLAUDE_CMD="$CLAUDE_CMD"
)

# Bitbucket credentials for HTTPS/API access
[[ -n "${BITBUCKET_USER:-}" ]] && ENV_VARS+=(-e BITBUCKET_USER="$BITBUCKET_USER")
[[ -n "${BITBUCKET_TOKEN:-}" ]] && ENV_VARS+=(-e BITBUCKET_TOKEN="$BITBUCKET_TOKEN")

# GCP: pass access token and ADC path for Artifact Registry auth inside container
if command -v gcloud &>/dev/null; then
    GCP_TOKEN=$(gcloud auth print-access-token 2>/dev/null || true)
    [[ -n "$GCP_TOKEN" ]] && ENV_VARS+=(-e "GCP_ACCESS_TOKEN=$GCP_TOKEN")
fi
if [[ -f "$HOME/.config/gcloud/application_default_credentials.json" ]]; then
    ENV_VARS+=(-e "GOOGLE_APPLICATION_CREDENTIALS=$CLAUDE_HOME/.config/gcloud/application_default_credentials.json")
fi

echo "Sandbox: ${WORKSPACE##*/}"

docker run -it --rm \
    "${MOUNTS[@]}" \
    "${ENV_VARS[@]}" \
    "$IMAGE_NAME" \
    ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}
