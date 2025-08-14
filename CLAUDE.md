# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

This repository serves as a troubleshooting workspace for Platform Engineers managing OpenShift clusters running on HyperShift. HyperShift enables hosting OpenShift control planes as workloads on a management (hub) cluster, with worker nodes running in separate hosted clusters.

## Key Architecture Knowledge

### Dual-Cluster Architecture
- **Hub/Management Cluster**: Runs control planes as pods in `clusters-<clustername>` namespaces
- **Hosted Clusters**: Contains only worker nodes and application workloads
- Control plane and worker nodes are in separate clusters, connected via Konnectivity proxy

### Critical Namespaces (Hub Cluster)
- `hypershift`: HyperShift operator
- `clusters`: HostedCluster and NodePool resources  
- `clusters-<name>`: Individual hosted control planes

### Resource Hierarchy
```
HostedCluster (clusters namespace)
  → Creates control plane namespace (clusters-<name>)
  → References NodePools
  → Manages ClusterVersion

NodePool (clusters namespace)
  → Creates MachineSets
  → Scales Machines
  → Configures Worker Nodes
```

## Essential Commands

### Initial Diagnostics
```bash
# Comprehensive cluster dump (ALWAYS start with this)
CLUSTER_NAME="<cluster-name>"
CLUSTER_NS="clusters"
hypershift dump cluster \
  --name "${CLUSTER_NAME}" \
  --namespace "${CLUSTER_NS}" \
  --dump-guest-cluster \
  --artifact-dir "/tmp/dump-${CLUSTER_NAME}-$(date +%Y%m%d-%H%M%S)"
```

### Context Management
```bash
# Generate hosted cluster kubeconfig
hypershift create kubeconfig \
  --name ${CLUSTER_NAME} \
  --namespace ${CLUSTER_NS} > ~/.kube/${CLUSTER_NAME}.kubeconfig

# Switch contexts
kubectl config use-context <hub-context>      # For hub cluster
kubectl config use-context <hosted-context>   # For hosted cluster
kubectl config current-context                # Verify current context
```

### Control Plane Health Checks (Hub Cluster)
```bash
# Check HostedCluster status
oc get hostedcluster -n ${CLUSTER_NS} ${CLUSTER_NAME}
oc describe hostedcluster -n ${CLUSTER_NS} ${CLUSTER_NAME}

# Examine control plane pods
CONTROL_PLANE_NS="clusters-${CLUSTER_NAME}"
oc get pods -n ${CONTROL_PLANE_NS}

# Check critical components
for component in kube-apiserver etcd kube-controller-manager kube-scheduler openshift-apiserver; do
  oc get pods -n ${CONTROL_PLANE_NS} -l app=${component}
  oc logs -n ${CONTROL_PLANE_NS} -l app=${component} --tail=50
done

# etcd health check
oc exec -n ${CONTROL_PLANE_NS} -c etcd etcd-0 -- etcdctl \
  --cacert=/etc/etcd/tls/etcd-ca/ca.crt \
  --cert=/etc/etcd/tls/client/etcd-client.crt \
  --key=/etc/etcd/tls/client/etcd-client.key \
  endpoint health
```

### Node Troubleshooting
```bash
# Hub cluster checks
oc get nodepool -n ${CLUSTER_NS} -l cluster.x-k8s.io/cluster-name=${CLUSTER_NAME}
oc get machines -n ${CONTROL_PLANE_NS}
oc get machinesets -n ${CONTROL_PLANE_NS}

# Hosted cluster checks (after switching context)
oc get nodes -o wide
oc describe node <node-name>
oc debug node/<node-name> -- chroot /host journalctl -u kubelet -n 100
```

### Emergency Operations
```bash
# Restart control plane components
oc annotate hostedcluster -n ${CLUSTER_NS} ${CLUSTER_NAME} \
  hypershift.openshift.io/restart-date="$(date)" --overwrite

# Pause reconciliation
oc patch hostedcluster -n ${CLUSTER_NS} ${CLUSTER_NAME} \
  --type merge -p '{"spec":{"pausedUntil":"true"}}'

# Resume reconciliation  
oc patch hostedcluster -n ${CLUSTER_NS} ${CLUSTER_NAME} \
  --type merge -p '{"spec":{"pausedUntil":null}}'

# Scale NodePool
oc scale nodepool -n ${CLUSTER_NS} <nodepool-name> --replicas=<count>
```

## Troubleshooting Decision Flow

### Problem Classification
1. **Control plane issues** → Primary focus: Hub cluster (`clusters-<name>` namespace)
2. **Worker node issues** → Check both hub (NodePool/Machine) and hosted clusters
3. **Networking issues** → Investigate Konnectivity (hub) and CNI (hosted)
4. **Application issues** → Primary focus: Hosted cluster
5. **Upgrade/scaling issues** → Primary focus: Hub cluster (HostedCluster/NodePool)

### Investigation Sequence
1. Identify affected cluster and gather initial context
2. Run `hypershift dump` for comprehensive diagnostics
3. Check relevant namespace based on problem domain
4. Follow resource chain: HostedCluster → NodePool → Machine → Node
5. Examine logs for error patterns
6. Test remediation in non-production if possible

## Key Troubleshooting Patterns

| Symptom | Primary Location | Key Checks |
|---------|-----------------|------------|
| API timeout | Hub: Control plane namespace | kube-apiserver pods, service endpoints |
| Nodes NotReady | Both clusters | NodePool status, Machine resources, kubelet logs |
| etcd alarms | Hub: Control plane namespace | etcd pod logs, disk space, latency |
| Operator degraded | Hosted cluster | Operator pods, ClusterOperator status |
| Network unreachable | Both clusters | Konnectivity, CNI pods, security groups |
| Upgrade stuck | Hub cluster | HostedCluster conditions, CVO logs |

## Important Considerations

- **ALWAYS verify cluster context** before executing commands
- **Start with `hypershift dump`** for comprehensive data collection  
- **Check both hub and hosted clusters** for most issues
- **Control planes run in hub**, workers run in hosted clusters
- **Document findings** with cluster names, namespaces, and exact errors
- **Test fixes in non-production** when possible
- **Use kubectl/oc interchangeably** - both work with OpenShift

## Safety Guidelines

Before making changes:
1. Confirm correct cluster and namespace context
2. Document current state
3. Have a rollback plan
4. Communicate with stakeholders for production changes
5. Save diagnostic data before modifications