# Claude Code Orchestration System Design
## For HyperShift Incident Response

### Executive Summary

This document outlines a system design that enables Platform Engineers to orchestrate Claude Code troubleshooting agents running as pods within specific OpenShift clusters (hub or hosted), while respecting the security boundary between insecure and secure zones.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INSECURE ZONE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [Platform Engineer Workstation]                                   │
│            │                                                        │
│            ├──► Claude Code CLI (local)                           │
│            │    └─► Creates troubleshooting request               │
│            │                                                        │
│            └──► Git Push ──► GitHub Repository                    │
│                               ├── /requests/{timestamp}.yaml       │
│                               ├── /manifests/                      │
│                               └── /results/                        │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                         NETWORK BOUNDARY                            │
├─────────────────────────────────────────────────────────────────────┤
│                         SECURE ZONE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [GitHub Actions]                                                  │
│       └──► Build Claude Code Container Image                       │
│            └──► Push to Internal Registry                          │
│                                                                     │
│  [ArgoCD]                                                          │
│       ├──► Monitors /manifests/ directory                          │
│       └──► Deploys Claude Code pods to target clusters            │
│                                                                     │
│  [Hub Cluster]                          [Hosted Cluster N]         │
│   ├── claude-warroom namespace           ├── claude-warroom ns    │
│   │   ├── Claude Code Pod                │   ├── Claude Code Pod  │
│   │   ├── Request Processor              │   ├── Request Processor│
│   │   └── Result Publisher               │   └── Result Publisher │
│   └── Control Planes                     └── Worker Nodes         │
│                                                                     │
│  [Secure Admin Workstation]                                        │
│       └──► Monitor results via ArgoCD UI or kubectl               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## System Components

### 1. Request Orchestrator (Insecure Zone)

**Purpose**: CLI tool for platform engineers to create and submit troubleshooting requests

**Components**:
- `claude-warroom` CLI wrapper
- Request template generator
- Git automation scripts

**Functionality**:
```yaml
# Example request format: /requests/2024-01-15-1430-api-timeout.yaml
apiVersion: warroom.intility.io/v1
kind: TroubleshootingRequest
metadata:
  name: api-timeout-investigation
  timestamp: "2024-01-15T14:30:00Z"
  engineer: "platform-engineer-1"
spec:
  targetCluster: 
    type: hub  # or "hosted"
    name: production-hub  # or specific hosted cluster name
  issue:
    category: "api-timeout"
    description: "API server experiencing 30s+ response times"
    affectedResources:
      - "hosted-cluster-prod-1"
      - "hosted-cluster-prod-2"
  investigation:
    prompt: |
      Investigate API server timeout issues for hosted-cluster-prod-1.
      Start with control plane health checks in namespace clusters-prod-1.
      Follow the HyperShift troubleshooting strategy for API issues.
    allowedTools:
      - bash
      - read
      - grep
      - write
    timeout: 1800  # 30 minutes
  output:
    format: "markdown"
    destination: "/results/2024-01-15-1430-api-timeout/"
```

### 2. Claude Code Container Image

**Base Dockerfile**:
```dockerfile
FROM registry.access.redhat.com/ubi9/nodejs-18:latest

USER root

# Install system dependencies
RUN dnf install -y \
    git \
    ripgrep \
    jq \
    && dnf clean all

# Install OpenShift CLI
RUN curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz | \
    tar -xz -C /usr/local/bin

# Install HyperShift CLI
RUN curl -L https://github.com/openshift/hypershift/releases/latest/download/hypershift-linux-amd64 \
    -o /usr/local/bin/hypershift && \
    chmod +x /usr/local/bin/hypershift

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Copy troubleshooting context
COPY claude-context/ /opt/claude-context/
COPY scripts/ /opt/scripts/

# Switch to non-root user
USER 1001

WORKDIR /workspace

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
```

### 3. Request Processor Pod

**Purpose**: Monitors for new troubleshooting requests and executes Claude Code

**Key Features**:
- Runs as a StatefulSet for persistence
- Monitors `/requests/` directory via ConfigMap or Git sync
- Executes Claude Code in headless mode
- Publishes results back to Git

**Kubernetes Manifest Structure**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: claude-processor
  namespace: claude-warroom
spec:
  serviceName: claude-processor
  replicas: 1
  template:
    spec:
      serviceAccountName: claude-warroom-sa
      containers:
      - name: claude-code
        image: internal-registry/claude-code:latest
        env:
        - name: ANTHROPIC_API_KEY
          valueFrom:
            secretKeyRef:
              name: claude-api-secret
              key: api-key
        - name: CLUSTER_TYPE
          value: "hub"  # or "hosted"
        - name: CLUSTER_NAME
          value: "production-hub"
        volumeMounts:
        - name: requests
          mountPath: /requests
        - name: results
          mountPath: /results
        - name: claude-context
          mountPath: /opt/claude-context
      - name: git-sync
        image: registry.k8s.io/git-sync/git-sync:v4.0.0
        volumeMounts:
        - name: git-repo
          mountPath: /git
```

### 4. Result Publisher

**Purpose**: Collects Claude Code outputs and publishes them for retrieval

**Options**:
1. **Git-based**: Push results to `/results/` directory in GitHub
2. **S3-compatible**: Upload to object storage accessible from both zones
3. **ConfigMap/Secret**: Store small results directly in Kubernetes

### 5. ArgoCD Applications

**Hub Cluster Application**:
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
    server: https://hub-cluster-api:6443
    namespace: claude-warroom
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Operational Workflows

### Workflow 1: Ad-hoc Troubleshooting

1. **Engineer creates request** (Insecure Zone):
   ```bash
   claude-warroom create --cluster hub \
     --issue "API timeout" \
     --prompt "Investigate control plane health"
   ```

2. **Request pushed to GitHub**:
   - Creates YAML in `/requests/pending/`
   - Triggers GitHub Actions workflow

3. **ArgoCD syncs** (Secure Zone):
   - Detects new request ConfigMap
   - Updates Claude processor pod

4. **Claude executes investigation**:
   - Runs diagnostic commands
   - Analyzes logs and metrics
   - Generates report

5. **Results published**:
   - Markdown report to `/results/`
   - Git commit with findings
   - Optional: Slack notification

6. **Engineer reviews results**:
   - Pull latest from GitHub
   - Or view in ArgoCD UI

### Workflow 2: Persistent Troubleshooting Session

1. **Deploy persistent Claude pod**:
   ```bash
   claude-warroom session start \
     --cluster hosted-prod-1 \
     --duration 2h
   ```

2. **Creates Job with extended timeout**:
   - Pod remains running for interactive work
   - Accessible via `kubectl exec`

3. **Engineer connects from SAW**:
   ```bash
   kubectl exec -it claude-session-xyz -- \
     claude -p "Continue investigating node issues"
   ```

### Workflow 3: Cross-Cluster Investigation

1. **Submit multi-cluster request**:
   ```yaml
   spec:
     targetClusters:
       - type: hub
         name: production-hub
       - type: hosted
         name: prod-cluster-1
     coordination:
       mode: sequential  # or parallel
   ```

2. **Orchestrator creates**:
   - Separate Claude pods in each cluster
   - Shared result aggregation job

## Security Considerations

### 1. API Key Management
- Store in Kubernetes Secret
- Rotate regularly via sealed-secrets
- Audit usage through Anthropic dashboard

### 2. RBAC Configuration
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: claude-warroom-investigator
rules:
  - apiGroups: ["*"]
    resources: ["pods", "logs", "events", "nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/exec", "pods/portforward"]
    verbs: ["create"]  # For debug commands
  - apiGroups: ["hypershift.openshift.io"]
    resources: ["hostedclusters", "nodepools"]
    verbs: ["get", "list", "describe"]
```

### 3. Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: claude-warroom-isolation
spec:
  podSelector:
    matchLabels:
      app: claude-code
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: openshift-dns
  - to:
    - podSelector: {}  # Allow cluster-internal traffic
  - ports:
    - protocol: TCP
      port: 443  # HTTPS for API calls
```

### 4. Audit Logging
- All Claude Code executions logged
- Commands executed tracked in annotations
- Results versioned in Git

## Implementation Phases

### Phase 1: MVP (Week 1-2)
- Basic Claude Code container image
- Manual deployment to hub cluster
- Simple request/response via ConfigMaps
- Basic RBAC and ServiceAccount

### Phase 2: Automation (Week 3-4)
- GitHub Actions for image building
- ArgoCD application setup
- Request orchestrator CLI tool
- Git-sync for request processing

### Phase 3: Enhanced Features (Week 5-6)
- Multi-cluster coordination
- Persistent session support
- Result aggregation and reporting
- Slack/email notifications

### Phase 4: Production Hardening (Week 7-8)
- Security scanning and compliance
- Performance optimization
- Monitoring and alerting
- Documentation and training

## Alternative Approaches Considered

### 1. Direct API Integration
- **Pros**: More control, custom UI possible
- **Cons**: Requires more development, less flexibility

### 2. Kubernetes Operator
- **Pros**: Native Kubernetes integration, CRD-based
- **Cons**: Complex to develop, overkill for this use case

### 3. Jenkins/Tekton Pipelines
- **Pros**: Existing CI/CD integration
- **Cons**: Less interactive, harder to troubleshoot

## Success Criteria

1. **Response Time**: < 5 minutes from request to Claude Code execution
2. **Availability**: 99% uptime for troubleshooting capability
3. **Security**: Zero unauthorized access incidents
4. **Usability**: Platform engineers can troubleshoot without SAW access
5. **Effectiveness**: 70% reduction in MTTR for HyperShift issues

## Next Steps

1. Review and approve design with security team
2. Set up GitHub repository structure
3. Create initial Claude Code container image
4. Deploy MVP to development hub cluster
5. Test with sample troubleshooting scenarios
6. Iterate based on platform engineer feedback

## Appendix: Example Commands

### Local CLI Usage
```bash
# Initialize warroom
claude-warroom init --github-repo intility/devinfra-claude-warroom

# Create investigation request
claude-warroom investigate \
  --cluster hub \
  --namespace clusters-prod-1 \
  --issue "etcd latency" \
  --strategy "control-plane-health"

# Check status
claude-warroom status --request-id req-12345

# Retrieve results
claude-warroom get-results --request-id req-12345
```

### Monitoring Commands
```bash
# From Secure Admin Workstation
kubectl get pods -n claude-warroom
kubectl logs -n claude-warroom claude-processor-0
kubectl describe cm -n claude-warroom claude-results
```