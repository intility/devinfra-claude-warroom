Investigate NotReady nodes in cluster ${HOSTED_CLUSTER_NAME}.
Start with hub cluster checks, then proceed to hosted cluster if accessible.

Hub Cluster Investigation:

1. Check NodePool health:
   - Run: oc get nodepool -n clusters ${HOSTED_CLUSTER_NAME}
   - Run: oc describe nodepool -n clusters ${HOSTED_CLUSTER_NAME} ${NODEPOOL_NAME}
   - Look for any degraded conditions or configuration issues

2. Verify Machine status:
   - Run: oc get machines -n clusters-${HOSTED_CLUSTER_NAME} -o wide
   - Identify machines corresponding to NotReady nodes
   - For each problematic machine: oc describe machine -n clusters-${HOSTED_CLUSTER_NAME} <machine-name>

3. Check MachineSet if applicable:
   - Run: oc get machinesets -n clusters-${HOSTED_CLUSTER_NAME}
   - Verify replicas and ready counts match expected values

Hosted Cluster Investigation (if accessible):

4. Get node status:
   - Run: oc get nodes -o wide
   - Identify all NotReady nodes
   - For each NotReady node: oc describe node <node-name>

5. Check node conditions:
   - Look for conditions: Ready, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable
   - Check last heartbeat times
   - Review any error messages in conditions

6. Examine kubelet status:
   - If debug access available: oc debug node/<node-name> -- chroot /host systemctl status kubelet
   - Check kubelet logs: oc debug node/<node-name> -- chroot /host journalctl -u kubelet -n 50
   - Look for authentication errors, API connectivity issues, or container runtime problems

7. Check system resources:
   - Run: oc adm top nodes
   - Look for resource exhaustion
   - Check if nodes are under memory or CPU pressure

8. Network connectivity:
   - Verify node can reach API server
   - Check CNI pod status on the node
   - Test inter-node connectivity if possible

9. Recent events:
   - Run: oc get events --field-selector involvedObject.kind=Node --sort-by='.lastTimestamp'
   - Look for eviction, resource, or connectivity issues

Provide comprehensive analysis including:
- Root cause of NotReady state
- Immediate recovery actions
- Whether node replacement is needed
- Long-term stability improvements