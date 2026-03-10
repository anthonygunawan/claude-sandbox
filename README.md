# Claude Sandbox

Run Claude Code with `--dangerously-skip-permissions` safely inside a Docker container. Only your project directory is exposed — everything else on your machine is isolated.

## Quick Start (Monday)

### 1. Open Docker Desktop

### 2. Open Warp terminal and run:

```bash
# Load SSH key (Passwords app will prompt if needed)
ssh-add ~/.ssh/your-key

# Start sandbox on a project
claude-sandbox -w ~/projects/my-java-service
```

### 3. To control from phone:

```bash
claude-sandbox --remote -w ~/projects/my-java-service
```

Open the `https://claude.ai/code/session_...` URL on your phone.

## All Commands

```bash
# Interactive session in current directory
claude-sandbox

# Interactive session on a specific project
claude-sandbox -w ~/projects/my-java-service

# One-shot task (runs and exits)
claude-sandbox -p "fix all lint errors"

# Remote control from phone
claude-sandbox --remote

# Combine flags
claude-sandbox --remote -w ~/projects/my-java-service
claude-sandbox -w ~/projects/my-web-app -p "add unit tests for BffController"
```

## First-Time Setup (already done)

Only needed once. Included here for reference if you need to redo it.

```bash
# Build the image
cd ~/.claude/claude-sandbox
docker build -t claude-sandbox .

# Add alias (already in your .zshrc)
echo 'alias claude-sandbox="~/.claude/claude-sandbox/claude-sandbox.sh"' >> ~/.zshrc
source ~/.zshrc
```

### Prerequisites

- Docker Desktop installed and running
- `BITBUCKET_USER` and `BITBUCKET_TOKEN` exported (already in `.zshrc`)
- SSH key loaded: `ssh-add ~/.ssh/your-key`
- Logged into Claude Code (session stored in `~/.claude.json`)

## What carries over from host

| Resource | Access |
|---|---|
| Project files | read/write |
| Claude settings, memory, plugins | read/write |
| Claude auth session (`.claude.json`) | read-only (copied + patched) |
| Maven local repo (`publishToMavenLocal`) | read/write |
| Gradle cache + wrapper | read/write |
| SSH auth (Bitbucket) | agent forwarding |
| Git identity (`.gitconfig`) | read-only |
| Bitbucket credentials | env vars |
| GCP credentials (Artifact Registry) | read-only mount + access token + gcloud shim |
| npm / pip cache | persisted via Docker volumes |

## What's isolated

The container **cannot** access:

- Host filesystem outside the mounted project
- `~/.ssh` private keys (agent forwarding used instead)
- Other projects (unless you mount a parent directory)
- System files and configuration

## Rebuilding

Only needed after modifying `Dockerfile` or `entrypoint.sh`. Changes to `claude-sandbox.sh` take effect immediately (no rebuild needed).

```bash
docker build -t claude-sandbox ~/.claude/claude-sandbox
```

## Troubleshooting

**"Claude configuration file not found"** — `.claude.json` not mounted correctly. Rebuild the image.

**Auth/login prompt inside container** — Your Claude session expired. Run `claude` on your Mac (outside container) to re-login, then retry the sandbox.

**"Permission denied" on git push** — SSH key not loaded. Run `ssh-add ~/.ssh/your-key` on your Mac.

**Gradle/Maven can't find local artifacts** — Make sure `~/.m2` and `~/.gradle` exist on your Mac. The sandbox mounts them directly.

## Cleanup

```bash
# Remove cached volumes
docker volume rm claude-npm-cache claude-pip-cache

# Remove image
docker rmi claude-sandbox
```
