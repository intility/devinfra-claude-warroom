#!/bin/bash

# Helper script to trigger Claude Code investigations
# Usage: ./trigger-investigation.sh [ISSUE_TYPE] [CLUSTER_NAME] [OPTIONS]

set -e

# Default values
ISSUE_TYPE="${1:-comprehensive-dump}"
CLUSTER_NAME="${2:-production}"
CLUSTER_TYPE="${3:-hub}"
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
BRANCH="main"

# Parse additional options
HOSTED_CLUSTER_NAME="${HOSTED_CLUSTER_NAME:-$CLUSTER_NAME}"
NAMESPACE="${NAMESPACE:-clusters}"
NODEPOOL_NAME="${NODEPOOL_NAME:-default}"
TARGET_REPLICAS="${TARGET_REPLICAS:-3}"
TRIGGERED_BY="${USER:-manual}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Claude Code Investigation Trigger ===${NC}"
echo "Issue Type: $ISSUE_TYPE"
echo "Cluster: $CLUSTER_NAME ($CLUSTER_TYPE)"
echo "Timestamp: $TIMESTAMP"
echo ""

# Available investigation types
VALID_TYPES=(
    "comprehensive-dump"
    "control-plane-health"
    "api-unreachable"
    "nodes-not-joining"
    "nodes-not-ready"
    "etcd-performance"
    "pod-scheduling-failures"
    "operator-degraded"
    "network-connectivity"
    "cluster-upgrade-stuck"
    "hosted-cluster-partial"
    "control-plane-restart"
    "pause-reconciliation"
    "scale-nodepool"
)

# Validate issue type
if [[ ! " ${VALID_TYPES[@]} " =~ " ${ISSUE_TYPE} " ]]; then
    echo -e "${YELLOW}Warning: Unknown issue type '${ISSUE_TYPE}'${NC}"
    echo "Valid types: ${VALID_TYPES[*]}"
    echo ""
fi

# Create job override file
JOB_FILE="manifests/${CLUSTER_TYPE}/job-override-${TIMESTAMP}.yaml"

cat > "$JOB_FILE" <<EOF
# Auto-generated investigation job
# Timestamp: $TIMESTAMP
# Triggered by: $TRIGGERED_BY
apiVersion: batch/v1
kind: Job
metadata:
  name: claude-investigate-${TIMESTAMP}
  namespace: claude-warroom
  labels:
    app: claude-code
    investigation-type: "${ISSUE_TYPE}"
    cluster: "${CLUSTER_NAME}"
  annotations:
    triggered-by: "${TRIGGERED_BY}"
    timestamp: "${TIMESTAMP}"
spec:
  ttlSecondsAfterFinished: 86400
  backoffLimit: 3
  activeDeadlineSeconds: 1800
  template:
    metadata:
      labels:
        app: claude-code
        investigation-type: "${ISSUE_TYPE}"
    spec:
      serviceAccountName: claude-warroom-sa
      restartPolicy: OnFailure
      containers:
      - name: claude-code
        image: ghcr.io/intility/claude-code:latest
        env:
        - name: ISSUE_TYPE
          value: "${ISSUE_TYPE}"
        - name: CLUSTER_NAME
          value: "${CLUSTER_NAME}"
        - name: CLUSTER_TYPE
          value: "${CLUSTER_TYPE}"
        - name: HOSTED_CLUSTER_NAME
          value: "${HOSTED_CLUSTER_NAME}"
        - name: NAMESPACE
          value: "${NAMESPACE}"
        - name: NODEPOOL_NAME
          value: "${NODEPOOL_NAME}"
        - name: TARGET_REPLICAS
          value: "${TARGET_REPLICAS}"
        - name: TRIGGERED_BY
          value: "${TRIGGERED_BY}"
        - name: TIMESTAMP
          value: "${TIMESTAMP}"
EOF

echo -e "${GREEN}Created job manifest: $JOB_FILE${NC}"

# Commit and push
echo -e "${YELLOW}Committing to Git...${NC}"
git add "$JOB_FILE"
git commit -m "Trigger investigation: ${ISSUE_TYPE} for ${CLUSTER_NAME}

Issue Type: ${ISSUE_TYPE}
Cluster: ${CLUSTER_NAME} (${CLUSTER_TYPE})
Triggered by: ${TRIGGERED_BY}
Timestamp: ${TIMESTAMP}"

echo -e "${YELLOW}Pushing to GitHub...${NC}"
git push origin "$BRANCH"

echo -e "${GREEN}✓ Investigation triggered successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. ArgoCD will sync the changes automatically"
echo "2. Monitor execution in Logfire:"
echo "   - Service: claude-warroom"
echo "   - Cluster: ${CLUSTER_NAME}"
echo "   - Investigation: ${ISSUE_TYPE}"
echo ""
echo "To check job status from SAW:"
echo "  kubectl get jobs -n claude-warroom"
echo "  kubectl logs -n claude-warroom job/claude-investigate-${TIMESTAMP}"