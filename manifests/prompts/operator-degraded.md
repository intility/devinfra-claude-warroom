Investigate degraded operator in cluster ${HOSTED_CLUSTER_NAME}.
Primary investigation in hosted cluster, check CVO in hub cluster if needed.

Hosted Cluster Investigation:

1. List all ClusterOperators and their status:
   - Run: oc get clusteroperators
   - Identify operators with Available=False, Progressing=True, or Degraded=True
   - For each degraded operator: oc describe clusteroperator <operator-name>

2. For degraded operators, check conditions:
   - Review the conditions section for specific error messages
   - Note the last transition times
   - Look for related objects mentioned in messages

3. Check operator pods:
   - Find operator namespace (usually openshift-<operator-name>)
   - Run: oc get pods -n <operator-namespace>
   - For failing pods: oc describe pod -n <operator-namespace> <pod-name>
   - Check logs: oc logs -n <operator-namespace> <pod-name> --tail=100

4. Review recent events:
   - Run: oc get events -n <operator-namespace> --sort-by='.lastTimestamp'
   - Look for errors, failures, or configuration issues

5. Check operator configuration:
   - Review operator CR: oc get <operator-cr> -n <operator-namespace> -o yaml
   - Look for misconfigurations or unsupported settings
   - Check if operator is paused or has manual overrides

6. Verify dependencies:
   - Check if required services are available
   - Verify RBAC permissions are correct
   - Ensure required CRDs are installed

7. Resource availability:
   - Check if operator pods have sufficient resources
   - Verify no resource quotas are blocking the operator
   - Check node availability for operator workloads

8. For specific common operators:
   - ingress: Check router pods, load balancer service
   - authentication: Verify OAuth pods, identity providers
   - monitoring: Check Prometheus, AlertManager
   - storage: Verify CSI drivers, storage classes

Hub Cluster Investigation (if needed):

9. Check Cluster Version Operator:
   - Run: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} | grep cluster-version
   - Check CVO logs if upgrade-related: oc logs -n clusters-${HOSTED_CLUSTER_NAME} <cvo-pod> --tail=50

10. Verify HostedCluster configuration:
    - Run: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} -o yaml
    - Check for any configuration affecting operators

Recovery steps:
- For each degraded operator, provide specific remediation
- Include commands to force operator reconciliation if needed
- Suggest rollback procedures if recent changes caused degradation
- Provide monitoring steps to verify recovery

Output should include:
- List of degraded operators with root causes
- Step-by-step recovery plan
- Preventive measures
- Escalation paths if standard recovery fails