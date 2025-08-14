Investigate stuck cluster upgrade for ${HOSTED_CLUSTER_NAME}.
Primary investigation in hub cluster, focusing on HostedCluster and CVO.

Hub Cluster Investigation:

1. Check HostedCluster upgrade status:
   - Run: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Check version and release fields
   - Run: oc describe hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Look for upgrade-related conditions and messages

2. Check ClusterVersion status:
   - Get current version: oc get clusterversion -o yaml
   - Look for conditions: Progressing, Available, Failing
   - Check message field for specific errors

3. Examine Cluster Version Operator:
   - Find CVO pod: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} | grep cluster-version
   - Check CVO logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} <cvo-pod> --tail=200
   - Look for: manifest errors, download failures, verification issues

4. Check individual operators upgrade status:
   - In hosted cluster: oc get clusteroperators
   - Identify operators stuck in Progressing=True
   - For stuck operators: oc describe clusteroperator <operator-name>

5. Review control plane component updates:
   - Check if control plane pods are updating: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -o wide
   - Look for pods with mixed versions
   - Check for pods in ImagePullBackOff or CrashLoopBackOff

6. Verify image availability:
   - Check if upgrade images are accessible
   - Look for image pull errors in pod events
   - Verify registry credentials if using private registry

7. Check for paused reconciliation:
   - Verify HostedCluster isn't paused: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} -o yaml | grep pausedUntil
   - Check if any manual overrides are blocking upgrade

8. Resource availability:
   - Verify sufficient resources for new pods
   - Check if PodDisruptionBudgets are blocking rollout
   - Ensure nodes have capacity for upgraded components

9. Review upgrade preconditions:
   - Check if all operators were healthy before upgrade
   - Verify no critical alerts are firing
   - Ensure etcd is healthy and has been recently backed up

10. Check NodePool upgrade status:
    - Run: oc get nodepool -n clusters ${HOSTED_CLUSTER_NAME}
    - Verify worker nodes are upgrading if required
    - Check for stuck machine replacements

Common upgrade blockers:
- Failing operator preventing progression
- Image pull failures
- Insufficient resources
- Network issues preventing image downloads
- Validation failures
- Custom modifications conflicting with upgrade

Recovery actions:
- Force operator reconciliation
- Clear stuck conditions
- Manual intervention steps
- Rollback procedures if needed

Provide structured output with:
- Current upgrade state and target version
- Specific component blocking upgrade
- Root cause analysis
- Step-by-step recovery plan
- Estimated time to complete upgrade
- Preventive measures for future upgrades