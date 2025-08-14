# HyperShift Troubleshooting Strategy for Claude Code

## Executive Summary

This strategy document provides a comprehensive approach for using Claude Code to troubleshoot OpenShift clusters running on HyperShift. The document addresses the unique dual-cluster architecture where control planes run on a hub (management) cluster while worker nodes operate as separate hosted clusters.

## Architecture Overview

### Key Components

1. **Hub/Management Cluster**
   - Runs the HyperShift Operator
   - Hosts control planes of multiple hosted clusters as pods
   - Each hosted cluster's control plane runs in namespace: `clusters-<clustername>`
   - Contains critical operators: Control Plane Operator, Cluster API providers

2. **Hosted Clusters**
   - Contains only worker nodes (data plane)
   - Control plane components accessed via hub cluster
   - Connected to hub via Konnectivity proxy
   - Runs application workloads

3. **Critical Resources**
   - `HostedCluster` CR: Defines control plane configuration
   - `NodePool` CR: Manages groups of worker nodes
   - `Machine/MachineSet`: Infrastructure provisioning resources

## Troubleshooting Decision Tree

### Step 1: Identify Problem Domain

```
Problem Reported
    ├── API/Control Plane Issues → Start with Hub Cluster
    ├── Node/Worker Issues → Check both Hub and Hosted
    ├── Networking Issues → Check both clusters
    ├── Application Issues → Start with Hosted Cluster
    └── Upgrade/Scaling Issues → Start with Hub Cluster
```

### Step 2: Context Determination

| Symptom | Primary Investigation | Secondary Investigation |
|---------|----------------------|------------------------|
| API unreachable | Hub: Control plane namespace | Hosted: Network connectivity |
| Nodes not joining | Hub: NodePool, Machine resources | Hosted: Kubelet logs |
| Pod scheduling failures | Hosted: Scheduler, nodes | Hub: Control plane health |
| etcd issues | Hub: etcd pods in control plane namespace | N/A |
| Operator degraded | Hosted: Operator pods | Hub: CVO in control plane namespace |
| Network connectivity | Hub: Konnectivity, OVN | Hosted: CNI, network policies |

## Diagnostic Workflows

### Workflow 1: Control Plane Health Check

**Location: Hub Cluster**

1. Check HostedCluster status:
   ```bash
   oc get hostedcluster -n clusters <cluster-name>
   oc describe hostedcluster -n clusters <cluster-name>
   ```

2. Examine control plane pods:
   ```bash
   oc get pods -n clusters-<clustername>
   oc logs -n clusters-<clustername> <pod-name>
   ```

3. Check critical components:
   - kube-apiserver
   - etcd (StatefulSet)
   - kube-controller-manager
   - kube-scheduler
   - openshift-apiserver

### Workflow 2: Node Issues

**Start: Hub Cluster**

1. Check NodePool status:
   ```bash
   oc get nodepool -n clusters <cluster-name>
   oc describe nodepool -n clusters <cluster-name> <nodepool-name>
   ```

2. Verify Machine resources:
   ```bash
   oc get machines -n clusters-<clustername>
   oc get machinesets -n clusters-<clustername>
   ```

3. Check Cluster API provider logs:
   ```bash
   oc logs -n clusters-<clustername> deployment/capi-provider-<provider>
   ```

**Then: Hosted Cluster**

4. Check node status:
   ```bash
   oc get nodes
   oc describe node <node-name>
   ```

5. Review kubelet logs (if SSH available):
   ```bash
   ssh core@<node-ip>
   sudo journalctl -u kubelet -f
   ```

### Workflow 3: Networking Issues

**Hub Cluster Investigation**

1. Check Konnectivity:
   ```bash
   oc logs -n clusters-<clustername> deployment/konnectivity-server
   oc logs -n clusters-<clustername> deployment/konnectivity-agent
   ```

2. Verify OVN status (if using OVN-Kubernetes):
   ```bash
   oc get pods -n clusters-<clustername> | grep ovn
   ```

**Hosted Cluster Investigation**

3. Check CNI pods:
   ```bash
   oc get pods -n openshift-ovn-kubernetes
   oc get pods -n openshift-sdn
   ```

4. Test connectivity:
   ```bash
   oc debug node/<node-name> -- chroot /host ping <target>
   ```

### Workflow 4: Comprehensive Data Collection

Use `hypershift dump` for complete diagnostics:

```bash
CLUSTERNAME="your-cluster-name"
CLUSTERNS="clusters"
ARTIFACT_DIR="/tmp/dump-${CLUSTERNAME}-$(date +%Y%m%d-%H%M%S)"

hypershift dump cluster \
    --name "${CLUSTERNAME}" \
    --namespace "${CLUSTERNS}" \
    --dump-guest-cluster \
    --artifact-dir "${ARTIFACT_DIR}"
```

## Resource Relationships

### Hub Cluster Resources
```
clusters (namespace)
    └── HostedCluster (CR)
        └── clusters-<clustername> (namespace)
            ├── Control plane pods
            ├── NodePool (CR)
            ├── Machines/MachineSets
            ├── Secrets/ConfigMaps
            └── Services/Endpoints
```

### Hosted Cluster Resources
```
Hosted Cluster
    ├── Nodes
    ├── Pods/Deployments
    ├── ClusterOperators
    └── Application workloads
```

## Context Switching Best Practices

### 1. Kubeconfig Management

```bash
# Generate hosted cluster kubeconfig
hypershift create kubeconfig \
    --name <cluster-name> \
    --namespace clusters > ~/.kube/<cluster-name>.kubeconfig

# Merge kubeconfigs
export KUBECONFIG=~/.kube/config:~/.kube/<cluster-name>.kubeconfig

# List contexts
kubectl config get-contexts

# Switch to hub cluster
kubectl config use-context <hub-context>

# Switch to hosted cluster
kubectl config use-context <hosted-context>
```

### 2. Namespace Awareness

Always verify your current context and namespace:
```bash
# Current context
kubectl config current-context

# Set default namespace for hub investigations
kubectl config set-context --current --namespace=clusters-<clustername>
```

## Common Issue Resolution Patterns

### Issue: Hosted Cluster Stuck in "Partial" State

**Investigation Path:**
1. Hub: Check HostedCluster conditions
2. Hub: Review control plane pod logs
3. Hub: Verify cloud credentials
4. Hub: Check Machine provisioning

**Resolution:**
- Fix credential issues
- Scale resources if needed
- Restart control plane components using annotation

### Issue: Nodes Not Ready

**Investigation Path:**
1. Hub: NodePool status
2. Hub: Machine/MachineSet status
3. Hosted: Node conditions
4. Hosted: Kubelet logs

**Resolution:**
- Fix infrastructure provisioning
- Resolve network connectivity
- Update MachineConfig if needed

### Issue: etcd Performance Problems

**Investigation Path:**
1. Hub: etcd pod metrics in control plane namespace
2. Hub: Storage performance
3. Hub: Resource allocation

**Resolution:**
- Increase etcd resources
- Optimize storage backend
- Consider etcd defragmentation

## Performance Optimization Points

### Hub Cluster
- Monitor control plane pod resource usage
- Ensure adequate node capacity for control planes
- Use node selectors/taints for control plane isolation

### Hosted Cluster
- Monitor node resource utilization
- Configure appropriate NodePool autoscaling
- Optimize CNI configuration

## Emergency Procedures

### Control Plane Restart
```bash
# Annotate HostedCluster to trigger restart
oc annotate hostedcluster -n clusters <name> \
    hypershift.openshift.io/restart-date="$(date)"
```

### Pause Reconciliation
```bash
# Pause for maintenance
oc patch hostedcluster -n clusters <name> \
    --type merge -p '{"spec":{"pausedUntil":"true"}}'

# Resume
oc patch hostedcluster -n clusters <name> \
    --type merge -p '{"spec":{"pausedUntil":null}}'
```

### Force NodePool Update
```bash
# Trigger node replacement
oc patch nodepool -n clusters <cluster-name> <nodepool-name> \
    --type merge -p '{"spec":{"management":{"replace":{"strategy":"RollingUpdate"}}}}'
```

## Monitoring Key Metrics

### Hub Cluster Metrics
- Control plane pod CPU/memory usage
- etcd latency and leader changes
- API server response times
- Konnectivity connection status

### Hosted Cluster Metrics
- Node availability and capacity
- Pod scheduling latency
- Network latency between nodes
- Storage performance

## Best Practices for Efficient Troubleshooting

1. **Always start with `hypershift dump`** for comprehensive data collection
2. **Check both clusters** - many issues span both hub and hosted
3. **Understand the namespace structure** - control planes live in `clusters-<name>`
4. **Monitor resource usage** on the hub cluster actively
5. **Keep kubeconfigs organized** with clear naming conventions
6. **Document issue patterns** specific to your environment
7. **Use labels and annotations** to track troubleshooting state

## Tool Commands Reference

### Essential HyperShift CLI Commands
```bash
# Cluster management
hypershift create cluster <provider> --name <name>
hypershift destroy cluster --name <name>
hypershift create kubeconfig --name <name>

# NodePool management
hypershift create nodepool <provider> --name <name> --cluster-name <cluster>
hypershift scale nodepool --name <name> --replicas <count>

# Diagnostics
hypershift dump cluster --name <name> --dump-guest-cluster

# Version information
hypershift version
```

### Critical oc/kubectl Commands
```bash
# Hub cluster investigation
oc get hostedcluster -A
oc get nodepool -A
oc get machines -n clusters-<name>
oc logs -n clusters-<name> <pod>

# Hosted cluster investigation
oc get nodes
oc get co  # ClusterOperators
oc debug node/<name>
oc adm top nodes
```

## Conclusion

Effective HyperShift troubleshooting requires understanding the architectural separation between hub and hosted clusters, knowing where each component runs, and following systematic diagnostic workflows. This strategy provides the foundation for Claude Code to efficiently navigate and resolve issues across the HyperShift infrastructure.