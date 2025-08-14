Investigate API server unreachability for hosted cluster ${HOSTED_CLUSTER_NAME}.
Primary investigation in hub cluster, control plane namespace: clusters-${HOSTED_CLUSTER_NAME}

Follow this diagnostic workflow:

1. Verify API server pod status:
   - Run: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-apiserver
   - Check if pods are Running and ready
   - Review logs: oc logs -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-apiserver --tail=200

2. Check service and endpoints:
   - Run: oc get svc -n clusters-${HOSTED_CLUSTER_NAME} | grep api
   - Run: oc get endpoints -n clusters-${HOSTED_CLUSTER_NAME} | grep api
   - Verify endpoints are populated with pod IPs

3. Examine load balancer/ingress:
   - Check external access configuration
   - Verify DNS resolution for api.${HOSTED_CLUSTER_NAME}.${BASE_DOMAIN}
   - Test connectivity from within the cluster

4. Check certificates:
   - Verify certificate expiration dates
   - Check certificate secrets in namespace
   - Look for certificate rotation issues

5. Review recent changes:
   - Check recent events: oc get events -n clusters-${HOSTED_CLUSTER_NAME} --sort-by='.lastTimestamp' | head -20
   - Look for recent config changes or updates

6. Test API connectivity:
   - From within hub cluster: curl -k https://<api-service-ip>:6443/healthz
   - Check response codes and latency

7. If API is responding but slow:
   - Check etcd performance
   - Review API server resource allocation
   - Look for throttling or rate limiting

Provide actionable recommendations including:
- Immediate steps to restore API access
- Root cause analysis
- Preventive measures
- Monitoring improvements