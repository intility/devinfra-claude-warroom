# DevInfra Claude Warroom

AI-powered troubleshooting system for OpenShift HyperShift clusters using Claude Code as an intelligent investigation agent.

## Overview

This repository implements a GitOps-based system that enables Platform Engineers to trigger Claude Code troubleshooting sessions in OpenShift clusters. Claude Code runs as Kubernetes Jobs with full observability through OpenTelemetry/Logfire.

## Architecture

- **Insecure Zone**: Platform engineers edit prompts and trigger investigations via Git
- **Secure Zone**: Claude Code runs as pods within target clusters with appropriate RBAC
- **Observability**: Full execution traces exported to Logfire via OpenTelemetry

## Quick Start

### 1. Prerequisites

- Access to GitHub repository
- ArgoCD deployed in target clusters
- Logfire configured for OTLP ingestion
- Anthropic API key

### 2. Initial Setup

```bash
# Clone repository
git clone https://github.com/intility/devinfra-claude-warroom
cd devinfra-claude-warroom

# Create API key secret in target cluster (from SAW)
kubectl create secret generic claude-api-secret \
  --from-literal=api-key=$ANTHROPIC_API_KEY \
  -n claude-warroom
```

### 3. Deploy ArgoCD Application

```bash
# Apply ArgoCD application (from SAW)
kubectl apply -f argocd/application-hub.yaml
```

### 4. Trigger Investigation

```bash
# From insecure workstation
./scripts/trigger-investigation.sh api-unreachable production-cluster hub

# Or manually edit and commit
vim manifests/hub/job-override.yaml
git add -A && git commit -m "Investigate issue" && git push
```

### 5. Monitor in Logfire

Filter by:
- Service: `claude-warroom`
- Cluster name
- Investigation type

## Available Investigation Types

| Type | Description |
|------|-------------|
| `comprehensive-dump` | Full cluster diagnostic data collection |
| `control-plane-health` | Control plane component health check |
| `api-unreachable` | API server connectivity issues |
| `nodes-not-joining` | Nodes failing to join cluster |
| `nodes-not-ready` | Nodes in NotReady state |
| `etcd-performance` | etcd performance analysis |
| `pod-scheduling-failures` | Pod scheduling issues |
| `operator-degraded` | Degraded operator investigation |
| `network-connectivity` | Network connectivity problems |
| `cluster-upgrade-stuck` | Stuck cluster upgrade |
| `hosted-cluster-partial` | Cluster stuck in Partial state |
| `control-plane-restart` | Emergency control plane restart |
| `pause-reconciliation` | Pause/resume cluster reconciliation |
| `scale-nodepool` | Scale NodePool up/down |

## Directory Structure

```
├── manifests/
│   ├── base/              # Shared K8s resources
│   ├── hub/               # Hub cluster specific
│   ├── hosted-*/          # Hosted cluster specific
│   └── prompts/           # Investigation prompt templates
├── scripts/               # Helper scripts
├── argocd/               # ArgoCD applications
├── Dockerfile            # Claude Code container image
└── .github/workflows/    # GitHub Actions for image build
```

## Customization

### Adding New Prompts

1. Create prompt file in `manifests/prompts/`
2. Add to `kustomization.yaml`
3. Use variables: `${CLUSTER_NAME}`, `${NAMESPACE}`, etc.
4. Commit and push

### Environment Variables

Jobs support these variables:
- `CLUSTER_TYPE`: hub or hosted
- `CLUSTER_NAME`: Target cluster name
- `HOSTED_CLUSTER_NAME`: For hub investigations
- `NAMESPACE`: Target namespace
- `ISSUE_TYPE`: Investigation type
- `NODEPOOL_NAME`: For scaling operations
- `TARGET_REPLICAS`: For scaling operations

## Security

- Claude Code runs with read-only RBAC (+ debug exec)
- API key stored in Kubernetes Secret
- Network policies restrict egress
- Jobs auto-cleanup after 24 hours

## Troubleshooting

### Job Fails to Start
- Check API key secret exists
- Verify RBAC is applied
- Check image pull permissions

### No Output in Logfire
- Verify OTEL_EXPORTER_OTLP_ENDPOINT
- Check network connectivity to Logfire
- Ensure Logfire collector is running

### Investigation Times Out
- Default timeout is 30 minutes
- Adjust `activeDeadlineSeconds` in job spec
- Break complex investigations into smaller parts

## Contributing

1. Fork the repository
2. Create feature branch
3. Add/modify prompts or features
4. Test in development cluster
5. Submit pull request

## License

Internal use only - Intility