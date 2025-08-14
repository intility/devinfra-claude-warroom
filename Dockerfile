FROM node:20-slim

WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    ripgrep \
    curl \
    jq \
    gettext-base \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install OpenShift and HyperShift CLIs (using x86_64 for now, will run under emulation on ARM)
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/openshift-client-linux.tar.gz | \
    tar -xz -C /usr/local/bin oc kubectl && \
    curl -L https://github.com/openshift/hypershift/releases/latest/download/hypershift-linux-amd64 \
    -o /usr/local/bin/hypershift && \
    chmod +x /usr/local/bin/hypershift /usr/local/bin/oc /usr/local/bin/kubectl

# Install Claude Code CLI globally
# Using the official Claude Code package from npm
RUN npm install -g @anthropic-ai/claude-code

# Verify installations (claude code doesn't have --version flag, using --help instead)
# Skip hypershift version check as it may fail in container build
RUN claude --help > /dev/null && \
    oc version --client

# Create non-root user
RUN useradd -m -u 1001 -s /bin/bash claude && \
    chown -R claude:claude /workspace

USER 1001

# Set environment variables for Claude Code
ENV CLAUDE_CODE_API_KEY=""
ENV OTEL_EXPORTER_OTLP_ENDPOINT=""
ENV OTEL_SERVICE_NAME="claude-warroom"

# Default entrypoint for Claude Code
ENTRYPOINT ["claude"]
CMD ["--help"]