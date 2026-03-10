# Claude Sandbox

A Docker container for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with `--dangerously-skip-permissions` in an isolated environment. Only your project directory is exposed — everything else on your machine stays safe.

## Quick Start

```bash
# Start an interactive session on a project
claude-sandbox -w ~/projects/my-java-service

# One-shot task
claude-sandbox -w ~/projects/myapp -p "fix all lint errors"

# Remote control from phone (opens a claude.ai session URL)
claude-sandbox --remote -w ~/projects/my-java-service
```

## Usage

```
claude-sandbox [OPTIONS] [CLAUDE_ARGS...]

Options:
  -w, --workspace PATH   Mount a specific directory (default: current directory)
  -p 'task'              Run a one-shot task non-interactively
  --remote               Start remote control session (control from claude.ai)
  -h, --help             Show help
```

### Examples

```bash
claude-sandbox                                          # interactive in cwd
claude-sandbox -w ~/projects/myapp                      # specific project
claude-sandbox -p "add unit tests for UserService"      # one-shot task
claude-sandbox --remote                                 # control from phone
claude-sandbox --remote -w ~/projects/myapp             # combine flags
```

## What's Inside

| Tool | Version |
|------|---------|
| Node.js | 20 (Alpine) |
| Java | 21 (default), 17 available via toolchains |
| Maven | latest Alpine package |
| Python | 3.x |
| Git, curl, jq, openssh | included |

## Host Integration

The container mounts and forwards resources from your host machine:

| Resource | How |
|----------|-----|
| Project files | read/write mount at `/workspace` |
| Claude settings & memory | read/write mount of `~/.claude` |
| Claude auth session | copied and patched at startup |
| Maven local repo (`~/.m2`) | read/write mount |
| Gradle cache (`~/.gradle`) | read/write mount |
| SSH keys | agent forwarding (keys never leave host) |
| Git config | read-only mount |
| Bitbucket credentials | `BITBUCKET_USER` / `BITBUCKET_TOKEN` env vars |
| GCP credentials | read-only mount + access token + gcloud shim |
| npm / pip caches | persisted via Docker volumes |

## Isolation

The container **cannot** access:

- Host filesystem outside the mounted project
- `~/.ssh` private keys (agent forwarding only)
- Other projects (unless you mount a parent directory)
- System files and host configuration

## Setup

### Prerequisites

- Docker Desktop installed and running
- `BITBUCKET_USER` and `BITBUCKET_TOKEN` exported in your shell
- SSH key loaded: `ssh-add <your-key>`
- Logged into Claude Code on host (`~/.claude.json` exists)

### Install

```bash
# Clone the repo
git clone git@github.com:anthonygunawan/claude-sandbox.git ~/.claude/claude-sandbox

# Build the image
docker build -t claude-sandbox ~/.claude/claude-sandbox

# Add alias to your shell
echo 'alias claude-sandbox="~/.claude/claude-sandbox/claude-sandbox.sh"' >> ~/.zshrc
source ~/.zshrc
```

## Rebuilding

Only needed after modifying `Dockerfile` or `entrypoint.sh`. Changes to `claude-sandbox.sh` take effect immediately.

```bash
docker build -t claude-sandbox ~/.claude/claude-sandbox
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Claude configuration file not found" | Rebuild the image |
| Auth/login prompt inside container | Run `claude` on host to re-login, then retry |
| "Permission denied" on git push | Load SSH key: `ssh-add <your-key>` |
| Gradle/Maven can't find local artifacts | Ensure `~/.m2` and `~/.gradle` exist on host |

## Cleanup

```bash
docker volume rm claude-npm-cache claude-pip-cache   # remove cached volumes
docker rmi claude-sandbox                            # remove image
```
