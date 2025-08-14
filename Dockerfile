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

# Install OpenShift and HyperShift CLIs
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | \
    tar -xz -C /usr/local/bin oc kubectl && \
    curl -L https://github.com/openshift/hypershift/releases/latest/download/hypershift-linux-amd64 \
    -o /usr/local/bin/hypershift && \
    chmod +x /usr/local/bin/hypershift /usr/local/bin/oc /usr/local/bin/kubectl

# Install Claude CLI globally
# Note: Using the correct package name for Claude CLI
RUN npm install -g @anthropic-ai/claude-cli

# Verify installations
RUN claude --version && \
    oc version --client && \
    hypershift version

# Create non-root user
RUN useradd -m -u 1001 -s /bin/bash claude && \
    chown -R claude:claude /workspace

USER 1001

# Default command keeps container running for exec access
CMD ["claude", "--help"]