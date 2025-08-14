# Control Plane Health Investigation

**Cluster:** `${CLUSTER_NAME}`  
**Control Plane Namespace:** `clusters-${HOSTED_CLUSTER_NAME}`  
**Investigation Type:** Control Plane Health Check

## Investigation Workflow

### 1. Check HostedCluster Status and Conditions

```bash
oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
oc describe hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
```

Analyze any degraded conditions or errors in the output.

### 2. Examine Control Plane Pods

```bash
oc get pods -n clusters-${HOSTED_CLUSTER_NAME}
```

- Identify any pods that are not `Running` or have high restart counts
- For problematic pods, check logs:
  ```bash
  oc logs -n clusters-${HOSTED_CLUSTER_NAME} <pod-name> --tail=100
  ```

### 3. Check Critical Components

Investigate each component individually:

- **kube-apiserver**: Authentication issues, certificate problems, resource constraints
- **etcd**: StatefulSet health, split-brain scenarios, performance issues
- **kube-controller-manager**: Reconciliation errors
- **kube-scheduler**: Scheduling failures
- **openshift-apiserver**: OAuth and API extensions functionality

### 4. Deep Dive for Problematic Components

For each component with issues:

```bash
# Review recent events
oc get events -n clusters-${HOSTED_CLUSTER_NAME} --sort-by='.lastTimestamp'

# Check resource usage
oc top pods -n clusters-${HOSTED_CLUSTER_NAME}

# Examine service endpoints
oc get endpoints -n clusters-${HOSTED_CLUSTER_NAME}
```

### 5. Generate Structured Report

Provide a comprehensive report including:

- **Executive Summary**: High-level findings
- **Root Cause**: Identified primary issue
- **Immediate Actions**: Steps to restore service
- **Resolution Commands**: Exact commands to execute
- **Prevention**: Long-term recommendations

> **Note:** This is a hub cluster investigation. The control plane runs here, not in the hosted cluster.