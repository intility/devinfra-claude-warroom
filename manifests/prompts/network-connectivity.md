Investigate network connectivity issues for cluster ${HOSTED_CLUSTER_NAME}.
This requires checking both hub cluster (Konnectivity, OVN control plane) and hosted cluster (CNI, network policies).

Hub Cluster Investigation:

1. Check Konnectivity components:
   - Server status: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=konnectivity-server
   - Server logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} deployment/konnectivity-server --tail=100
   - Look for connection errors, authentication issues, or proxy problems

2. Verify Konnectivity agents (if accessible):
   - Agent deployment: oc get deployment -n clusters-${HOSTED_CLUSTER_NAME} konnectivity-agent
   - Agent logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} deployment/konnectivity-agent --tail=100
   - Check for disconnections or communication errors

3. OVN control plane (if using OVN-Kubernetes):
   - Check OVN master: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} | grep ovn
   - OVN northbound DB: oc logs -n clusters-${HOSTED_CLUSTER_NAME} -l app=ovnkube-master --tail=50
   - Look for database sync issues or configuration problems

4. Service endpoints:
   - Verify endpoints: oc get endpoints -n clusters-${HOSTED_CLUSTER_NAME}
   - Check service connectivity within the cluster
   - Verify load balancer services are properly configured

Hosted Cluster Investigation:

5. Check CNI pods:
   - For OVN: oc get pods -n openshift-ovn-kubernetes
   - For OpenShift SDN: oc get pods -n openshift-sdn
   - Check for crashlooping or failing CNI pods
   - Review CNI logs: oc logs -n <cni-namespace> <cni-pod> --tail=100

6. Node network configuration:
   - Check node network status: oc get network.config.openshift.io cluster -o yaml
   - Verify cluster network CIDR configuration
   - Check service network configuration

7. Test pod-to-pod connectivity:
   - Create test pods in different nodes
   - Test connectivity: oc debug node/<node-name> -- chroot /host ping <target-pod-ip>
   - Verify no packet loss or high latency

8. Service connectivity:
   - Test service DNS resolution: oc debug node/<node-name> -- chroot /host nslookup kubernetes.default.svc.cluster.local
   - Verify services are accessible from pods
   - Check for DNS issues

9. Network policies:
   - List policies: oc get networkpolicy --all-namespaces
   - Check if policies are blocking required traffic
   - Verify ingress/egress rules

10. External connectivity:
    - Test outbound connectivity: oc debug node/<node-name> -- chroot /host curl -I https://www.google.com
    - Check NAT/firewall configuration
    - Verify proxy settings if applicable

11. Load balancer/Ingress:
    - Check ingress controller: oc get pods -n openshift-ingress
    - Verify load balancer service: oc get svc -n openshift-ingress
    - Test route connectivity

Common issues to check:
- MTU mismatches
- Firewall rules blocking traffic
- Incorrect VXLAN/Geneve configuration
- IP address conflicts
- Routes missing or misconfigured

Provide diagnosis with:
- Network component causing the issue
- Specific connectivity failures identified
- Remediation steps with commands
- Network configuration recommendations
- Monitoring improvements