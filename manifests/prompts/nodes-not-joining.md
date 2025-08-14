Investigate nodes not joining issue for cluster ${HOSTED_CLUSTER_NAME}.
This requires checking both hub cluster (NodePool, Machines) and potentially the hosted cluster.

Hub Cluster Investigation (Primary):

1. Check NodePool status:
   - Run: oc get nodepool -n clusters ${HOSTED_CLUSTER_NAME}
   - Run: oc describe nodepool -n clusters ${HOSTED_CLUSTER_NAME} ${NODEPOOL_NAME}
   - Look for scaling issues, error conditions, or configuration problems

2. Verify Machine resources:
   - Run: oc get machines -n clusters-${HOSTED_CLUSTER_NAME}
   - Run: oc get machinesets -n clusters-${HOSTED_CLUSTER_NAME}
   - Check machine phases (Provisioning, Provisioned, Running, Failed)
   - For failed machines: oc describe machine -n clusters-${HOSTED_CLUSTER_NAME} <machine-name>

3. Check Cluster API provider:
   - Identify provider: oc get deployment -n clusters-${HOSTED_CLUSTER_NAME} | grep capi-provider
   - Check provider logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} deployment/capi-provider-<provider> --tail=100
   - Look for infrastructure provisioning errors

4. Verify cloud/infrastructure resources:
   - Check if machines are actually created in the infrastructure
   - Verify quotas and limits aren't exceeded
   - Check network connectivity from infrastructure to cluster

5. Examine bootstrap process:
   - Check for ignition/cloud-init issues
   - Verify bootstrap credentials and configurations
   - Look for user-data secret: oc get secret -n clusters-${HOSTED_CLUSTER_NAME} | grep user-data

6. For machines that exist but nodes aren't joining:
   - Check Konnectivity: oc logs -n clusters-${HOSTED_CLUSTER_NAME} deployment/konnectivity-server --tail=50
   - Verify network path from nodes to API server
   - Check for certificate or authentication issues

If you have access to check the hosted cluster side:
   - Run: oc get nodes
   - For any nodes present: oc describe node <node-name>
   - Check for taint/toleration mismatches
   - Verify kubelet is running on the nodes

Provide a diagnosis with:
- Why nodes are failing to join
- Step-by-step remediation plan
- Infrastructure-specific considerations
- Preventive measures for the future