# Claude Code MVP Design - Simplified Implementation
## Quick Validation for HyperShift Troubleshooting

### Executive Summary

This simplified MVP design enables rapid testing of Claude Code as a troubleshooting agent in OpenShift clusters. The system uses ConfigMap-based prompt injection, Kubernetes Jobs, and native OpenTelemetry export to Logfire for observability.

## Simplified Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INSECURE ZONE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [Platform Engineer Workstation]                                   │
│            │                                                        │
│            ├──► Edit prompt in GitHub repo                         │
│            │    └── /manifests/hub/prompts-configmap.yaml         │
│            │                                                        │
│            └──► Git Push ──► GitHub Repository                    │
│                                                                     │
│  [Logfire Dashboard]                                               │
│            └──► View Claude Code execution traces                  │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                         NETWORK BOUNDARY                            │
├─────────────────────────────────────────────────────────────────────┤
│                         SECURE ZONE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [GitHub Packages Registry]                                        │
│       └──► Hosts pre-built Claude Code image                       │
│                                                                     │
│  [ArgoCD]                                                          │
│       ├──► Monitors /manifests/{hub,hosted-*}/ directories         │
│       └──► Syncs ConfigMaps and Jobs to target clusters            │
│                                                                     │
│  [Hub Cluster]                          [Hosted Cluster N]         │
│   ├── claude-warroom namespace           ├── claude-warroom ns    │
│   │   ├── Prompts ConfigMap              │   ├── Prompts ConfigMap│
│   │   ├── Context ConfigMap              │   ├── Context ConfigMap│
│   │   ├── Claude Code Job                │   ├── Claude Code Job  │
│   │   └── ServiceAccount + RBAC          │   └── ServiceAccount   │
│   │                                      │                        │
│   └── [Logfire Agent] ◄──────────────────┴── OTLP export          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Claude Code Base Image

Simple Dockerfile that can be built once and reused:

```dockerfile
FROM node:20-slim

WORKDIR /workspace

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    ripgrep \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install OpenShift and HyperShift CLIs
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | \
    tar -xz -C /usr/local/bin && \
    curl -L https://github.com/openshift/hypershift/releases/latest/download/hypershift-linux-amd64 \
    -o /usr/local/bin/hypershift && \
    chmod +x /usr/local/bin/hypershift

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Source environment variables from ConfigMap if exists\n\
if [ -f /config/env ]; then\n\
    source /config/env\n\
fi\n\
\n\
# Process prompt template with envsubst\n\
PROMPT_FILE="${PROMPT_FILE:-/prompts/default.txt}"\n\
if [ -f "$PROMPT_FILE" ]; then\n\
    PROCESSED_PROMPT=$(envsubst < "$PROMPT_FILE")\n\
else\n\
    PROCESSED_PROMPT="$CLAUDE_PROMPT"\n\
fi\n\
\n\
# Copy context files if mounted\n\
if [ -d /context ]; then\n\
    cp -r /context/* /workspace/\n\
fi\n\
\n\
# Run Claude Code in headless mode with OpenTelemetry\n\
claude -p "$PROCESSED_PROMPT" \\\n\
    --allowedTools bash,read,grep,write \\\n\
    --output-format stream-json\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
```

### 2. Prompt Templates ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: claude-prompts
  namespace: claude-warroom
data:
  # Template variables: ${CLUSTER_NAME}, ${NAMESPACE}, ${ISSUE_TYPE}, ${TIMESTAMP}
  
  default.txt: |
    You are troubleshooting cluster ${CLUSTER_NAME} at ${TIMESTAMP}.
    Follow the HyperShift troubleshooting strategy in CLAUDE.md.
    Start with a comprehensive diagnostic dump and identify the root cause.
    
  api-timeout.txt: |
    Investigate API timeout issues in cluster ${CLUSTER_NAME}.
    Focus on control plane namespace: ${NAMESPACE}
    
    Steps:
    1. Check HostedCluster status and conditions
    2. Examine kube-apiserver pod logs and metrics
    3. Verify etcd health and performance
    4. Check service endpoints and load balancer configuration
    5. Review recent changes or events
    
    Provide a summary with:
    - Root cause identification
    - Immediate remediation steps
    - Long-term recommendations
    
  node-notready.txt: |
    Investigate NotReady nodes in cluster ${CLUSTER_NAME}.
    
    Steps:
    1. List all nodes and their conditions
    2. For NotReady nodes, check:
       - NodePool status in namespace ${NAMESPACE}
       - Machine resources and provisioning status
       - Recent events related to the nodes
    3. If possible, check kubelet logs
    4. Verify network connectivity
    
    Provide actionable remediation steps.
    
  etcd-performance.txt: |
    Analyze etcd performance issues in cluster ${CLUSTER_NAME}.
    Control plane namespace: ${NAMESPACE}
    
    Steps:
    1. Check etcd pod status and resource usage
    2. Run etcd health checks
    3. Analyze etcd metrics (if available)
    4. Check for leader elections or member issues
    5. Review disk I/O and latency
    
    Recommend performance optimizations.
    
  custom-investigation.txt: |
    ${CUSTOM_PROMPT}
```

### 3. Context ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: claude-context
  namespace: claude-warroom
data:
  CLAUDE.md: |
    # CLAUDE.md - HyperShift Troubleshooting Context
    
    You are a troubleshooting agent for OpenShift HyperShift clusters.
    
    ## Environment
    - Cluster Type: ${CLUSTER_TYPE}  # hub or hosted
    - Cluster Name: ${CLUSTER_NAME}
    - Current Namespace: ${NAMESPACE}
    
    ## Available Commands
    - oc/kubectl: Full access via ServiceAccount
    - hypershift: HyperShift CLI for cluster operations
    - Standard Linux tools: grep, awk, sed, jq
    
    ## Troubleshooting Strategy
    [Include content from hypershift-troubleshooting-strategy.md]
    
  env: |
    # Environment variables for prompt templates
    export CLUSTER_TYPE="${CLUSTER_TYPE:-hub}"
    export CLUSTER_NAME="${CLUSTER_NAME:-production}"
    export NAMESPACE="${NAMESPACE:-clusters}"
    export TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    export ISSUE_TYPE="${ISSUE_TYPE:-general}"
```

### 4. Kubernetes Job Manifest

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: claude-investigate-${TIMESTAMP}
  namespace: claude-warroom
  labels:
    app: claude-code
    investigation: ${ISSUE_TYPE}
spec:
  ttlSecondsAfterFinished: 86400  # Clean up after 24 hours
  backoffLimit: 3  # Retry 3 times
  activeDeadlineSeconds: 1800  # 30 minute timeout
  template:
    metadata:
      labels:
        app: claude-code
      annotations:
        # Trigger new Job on ConfigMap change
        configmap/prompts-version: "${PROMPTS_VERSION}"
    spec:
      serviceAccountName: claude-warroom-sa
      restartPolicy: OnFailure
      containers:
      - name: claude-code
        image: ghcr.io/intility/claude-code:latest
        imagePullPolicy: Always
        env:
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: claude-api-secret
              key: api-key
        
        # OpenTelemetry configuration for Logfire
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://logfire-collector.monitoring:4318"
        - name: OTEL_EXPORTER_OTLP_PROTOCOL
          value: "http/protobuf"
        - name: OTEL_SERVICE_NAME
          value: "claude-warroom"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "cluster.name=${CLUSTER_NAME},cluster.type=${CLUSTER_TYPE},investigation.type=${ISSUE_TYPE}"
        
        # Prompt selection
        - name: PROMPT_FILE
          value: "/prompts/${ISSUE_TYPE}.txt"
        - name: CLAUDE_PROMPT
          value: "Fallback prompt if file not found"
        
        # Template variables
        - name: CLUSTER_TYPE
          value: "${CLUSTER_TYPE}"
        - name: CLUSTER_NAME
          value: "${CLUSTER_NAME}"
        - name: NAMESPACE
          value: "${NAMESPACE}"
        - name: ISSUE_TYPE
          value: "${ISSUE_TYPE}"
        - name: CUSTOM_PROMPT
          value: "${CUSTOM_PROMPT}"
        
        volumeMounts:
        - name: prompts
          mountPath: /prompts
        - name: context
          mountPath: /context
        - name: config
          mountPath: /config
        
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2"
      
      volumes:
      - name: prompts
        configMap:
          name: claude-prompts
      - name: context
        configMap:
          name: claude-context
      - name: config
        configMap:
          name: claude-context
          items:
          - key: env
            path: env
```

### 5. ServiceAccount and RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: claude-warroom-sa
  namespace: claude-warroom
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-warroom-investigator
rules:
  # Read-only access to most resources
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
  
  # Execute debug commands
  - apiGroups: [""]
    resources: ["pods/exec", "pods/log"]
    verbs: ["create", "get"]
  
  # HyperShift specific
  - apiGroups: ["hypershift.openshift.io"]
    resources: ["*"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: claude-warroom-investigator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: claude-warroom-investigator
subjects:
- kind: ServiceAccount
  name: claude-warroom-sa
  namespace: claude-warroom
```

### 6. Kustomization for Easy Management

```yaml
# /manifests/hub/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: claude-warroom

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - rbac.yaml
  - secret.yaml  # For API key
  - prompts-configmap.yaml
  - context-configmap.yaml
  - job.yaml

configMapGenerator:
  - name: claude-prompts
    files:
      - prompts/default.txt
      - prompts/api-timeout.txt
      - prompts/node-notready.txt
      - prompts/etcd-performance.txt
  
  - name: claude-context
    files:
      - context/CLAUDE.md
      - context/env

replacements:
  - source:
      kind: ConfigMap
      name: claude-prompts
      fieldPath: metadata.annotations.version
    targets:
      - select:
          kind: Job
        fieldPaths:
          - spec.template.metadata.annotations.[configmap/prompts-version]
```

### 7. ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: claude-warroom-hub
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/intility/devinfra-claude-warroom
    targetRevision: main
    path: manifests/hub
  destination:
    server: https://kubernetes.default.svc
    namespace: claude-warroom
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - Replace=true  # Replace Jobs on sync
```

## Operational Workflow (Simplified)

### 1. Trigger Investigation

Platform engineer edits the Job manifest or uses a helper script:

```bash
#!/bin/bash
# trigger-investigation.sh

ISSUE_TYPE="${1:-default}"
CUSTOM_PROMPT="${2:-}"
TIMESTAMP=$(date +%s)

# Update Job manifest with new values
cat > manifests/hub/job-override.yaml <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: claude-investigate-${TIMESTAMP}
  namespace: claude-warroom
spec:
  template:
    spec:
      containers:
      - name: claude-code
        env:
        - name: ISSUE_TYPE
          value: "${ISSUE_TYPE}"
        - name: CUSTOM_PROMPT
          value: "${CUSTOM_PROMPT}"
EOF

git add manifests/hub/job-override.yaml
git commit -m "Trigger ${ISSUE_TYPE} investigation"
git push

echo "Investigation triggered. Monitor in Logfire."
```

### 2. ArgoCD Sync

ArgoCD detects the change and:
1. Creates/updates the Job
2. Job pulls the latest ConfigMaps
3. Claude Code executes with the selected prompt

### 3. Monitor in Logfire

Platform engineer views real-time execution in Logfire:
- See Claude's thought process
- View executed commands
- Track tool usage
- Monitor errors and retries

## Directory Structure

```
devinfra-claude-warroom/
├── Dockerfile                     # Claude Code image (built once)
├── manifests/
│   ├── base/                     # Shared resources
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   └── rbac.yaml
│   ├── hub/                      # Hub cluster specific
│   │   ├── kustomization.yaml
│   │   ├── prompts/
│   │   │   ├── default.txt
│   │   │   ├── api-timeout.txt
│   │   │   └── node-notready.txt
│   │   ├── context/
│   │   │   ├── CLAUDE.md
│   │   │   └── env
│   │   └── job.yaml
│   └── hosted-prod-1/            # Hosted cluster specific
│       ├── kustomization.yaml
│       └── ...
├── scripts/
│   ├── trigger-investigation.sh
│   └── build-and-push.sh
└── .github/
    └── workflows/
        └── build-image.yaml      # Build Claude Code image
```

## Quick Start Guide

### 1. Initial Setup (One-time)

```bash
# Build and push Claude Code image
docker build -t ghcr.io/intility/claude-code:latest .
docker push ghcr.io/intility/claude-code:latest

# Create API key secret (from SAW)
kubectl create secret generic claude-api-secret \
  --from-literal=api-key=$ANTHROPIC_API_KEY \
  -n claude-warroom
```

### 2. Deploy with ArgoCD

```bash
# Create ArgoCD application
kubectl apply -f argocd-application.yaml
```

### 3. Trigger Investigation

Edit prompt in `manifests/hub/prompts/` or modify Job environment variables, then:

```bash
git add -A
git commit -m "Investigate API timeout issue"
git push
```

### 4. Monitor Results

Open Logfire dashboard and filter by:
- Service: `claude-warroom`
- Cluster: `production-hub`
- Investigation type: `api-timeout`

## Advantages of This Simplified Approach

1. **No Image Rebuilds**: Claude Code image is built once and reused
2. **GitOps Native**: All configuration via Git commits
3. **Observable**: Full execution trace in Logfire via OTLP
4. **Flexible**: Easy to add new prompt templates
5. **Fast Iteration**: Change prompts without rebuilding
6. **Secure**: API key in Kubernetes Secret, RBAC controlled
7. **Simple**: Minimal moving parts, easy to debug

## Testing Strategy

### Phase 1: Basic Validation
1. Deploy to dev cluster
2. Test with simple prompts (list pods, check nodes)
3. Verify Logfire integration works

### Phase 2: Troubleshooting Scenarios
1. Test each prompt template
2. Simulate common issues
3. Validate Claude's responses

### Phase 3: Production Readiness
1. Test with real incidents
2. Measure response quality
3. Optimize prompts based on results

## Next Steps

1. **Immediate**:
   - Build Claude Code Docker image
   - Set up GitHub Packages registry
   - Create initial prompt templates

2. **This Week**:
   - Deploy to development cluster
   - Test Logfire integration
   - Run first troubleshooting scenarios

3. **Next Week**:
   - Refine prompts based on results
   - Add more investigation templates
   - Document learnings