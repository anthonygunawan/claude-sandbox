FROM node:20-alpine

RUN apk add --no-cache \
    bash \
    curl \
    git \
    python3 \
    py3-pip \
    build-base \
    openjdk17 \
    maven \
    jq \
    openssh-client \
    sudo

RUN npm install -g @anthropic-ai/claude-code

# Match host macOS UID (501) so mounted files are owned correctly
RUN addgroup -S claude && adduser -S claude -G claude -u 501
RUN echo "claude ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

# Run as claude from the start — no user switching, no TTY issues
USER claude

ENTRYPOINT ["/entrypoint.sh"]
