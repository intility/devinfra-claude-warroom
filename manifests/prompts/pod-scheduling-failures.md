Investigate pod scheduling failures in hosted cluster ${HOSTED_CLUSTER_NAME}.
Primary investigation in hosted cluster, secondary check in hub cluster for control plane health.

Hosted Cluster Investigation (Primary):

1. Identify pending pods:
   - Run: oc get pods --all-namespaces --field-selector=status.phase=Pending
   - Note namespaces and pod names with scheduling issues
   - For each pending pod: oc describe pod -n <namespace> <pod-name>

2. Check scheduler events:
   - Look for events with reason: FailedScheduling
   - Common issues: Insufficient resources, node selectors, taints/tolerations
   - Run: oc get events --all-namespaces | grep FailedScheduling

3. Analyze node capacity:
   - Run: oc get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEMORY:.status.allocatable.memory,PODS:.status.allocatable.pods
   - Check node utilization: oc adm top nodes
   - Verify available capacity for pending pods

4. Check for node constraints:
   - List node taints: oc get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
   - Review node labels: oc get nodes --show-labels
   - Verify pod tolerations and node selectors match

5. Examine scheduler health:
   - Check scheduler pod status (in hub cluster): oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-scheduler
   - Review scheduler logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-scheduler --tail=50

6. Check for PodDisruptionBudgets:
   - Run: oc get pdb --all-namespaces
   - Verify PDBs aren't preventing scheduling

7. Review ResourceQuotas and LimitRanges:
   - Check namespace quotas: oc get resourcequota --all-namespaces
   - Verify limits: oc get limitrange --all-namespaces
   - Ensure quotas aren't exhausted

8. Check for pod affinity/anti-affinity conflicts:
   - Review pod specifications for complex affinity rules
   - Check if anti-affinity rules are preventing placement

9. Verify storage requirements:
   - Check if pods require specific storage classes
   - Verify PVCs can be satisfied: oc get pvc --all-namespaces | grep Pending

Hub Cluster Secondary Check:

10. Verify control plane health:
    - Quick check: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-scheduler
    - Ensure scheduler is running and healthy

Provide analysis with:
- Why pods are failing to schedule
- Immediate remediation (scale nodes, adjust resources, fix taints)
- Resource optimization recommendations
- Capacity planning suggestions