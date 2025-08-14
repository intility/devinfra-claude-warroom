Investigate hosted cluster stuck in "Partial" state: ${HOSTED_CLUSTER_NAME}.
Focus on hub cluster investigation to identify what's preventing full deployment.

Investigation workflow:

1. Check HostedCluster status and conditions:
   - Run: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Run: oc describe hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Review all conditions, especially:
     - Available
     - Progressing  
     - Degraded
     - InfrastructureReady
     - KubeConfigAvailable
     - ServicesAvailable

2. Review control plane pod status:
   - Run: oc get pods -n clusters-${HOSTED_CLUSTER_NAME}
   - Identify any pods that are:
     - Not running
     - CrashLooping
     - In ImagePullBackOff
     - Pending
   - For each problematic pod: oc describe pod -n clusters-${HOSTED_CLUSTER_NAME} <pod-name>

3. Check critical control plane components:
   - API Server: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-apiserver
   - etcd: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=etcd
   - Controller Manager: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-controller-manager
   - For each missing/failing component, check logs and events

4. Verify cloud credentials and permissions:
   - Check secret exists: oc get secret -n clusters-${HOSTED_CLUSTER_NAME} | grep credentials
   - Verify cloud provider authentication is working
   - Check CAPI provider logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} deployment/capi-provider-<provider> --tail=100

5. Check infrastructure provisioning:
   - Machines: oc get machines -n clusters-${HOSTED_CLUSTER_NAME}
   - MachineSets: oc get machinesets -n clusters-${HOSTED_CLUSTER_NAME}
   - For failed machines: oc describe machine -n clusters-${HOSTED_CLUSTER_NAME} <machine-name>
   - Look for quota issues, permission problems, or network configuration errors

6. Examine NodePool status:
   - Run: oc get nodepool -n clusters ${HOSTED_CLUSTER_NAME}
   - Check if nodes are being provisioned
   - Review NodePool conditions for errors

7. Check service availability:
   - Verify services are created: oc get svc -n clusters-${HOSTED_CLUSTER_NAME}
   - Check endpoints: oc get endpoints -n clusters-${HOSTED_CLUSTER_NAME}
   - Verify load balancers are provisioned (for cloud providers)

8. Review recent events:
   - Run: oc get events -n clusters-${HOSTED_CLUSTER_NAME} --sort-by='.lastTimestamp' | head -30
   - Look for recurring errors or failures
   - Check for resource creation failures

9. Validate configuration:
   - Check HostedCluster spec: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} -o yaml
   - Verify:
     - Platform configuration is correct
     - Network settings are valid
     - Service CIDRs don't conflict
     - Pull secret is valid

10. Check operator status:
    - Control Plane Operator: oc get pods -n hypershift | grep control-plane-operator
    - Check operator logs for errors related to this cluster
    - HyperShift Operator: oc logs -n hypershift deployment/hypershift-operator --tail=100 | grep ${HOSTED_CLUSTER_NAME}

Common causes of Partial state:
- Invalid cloud credentials
- Insufficient cloud quota
- Network misconfiguration
- Pull secret issues
- Certificate problems
- Resource constraints
- DNS configuration errors

Resolution steps:
- Fix identified configuration issues
- Restart stuck components
- Scale resources if needed
- Apply any missing configurations

Provide analysis with:
- Specific reason for Partial state
- Components that are failing
- Clear remediation steps
- Expected time to reach Available state
- Validation steps after fixes