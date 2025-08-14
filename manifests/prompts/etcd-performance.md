Investigate etcd performance issues in cluster ${HOSTED_CLUSTER_NAME}.
Focus on control plane namespace: clusters-${HOSTED_CLUSTER_NAME} in the hub cluster.

Comprehensive etcd diagnostic workflow:

1. Check etcd pod status:
   - Run: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=etcd
   - Verify all etcd members are Running
   - Check restart counts and age of pods

2. Examine etcd health:
   - Run health check: oc exec -n clusters-${HOSTED_CLUSTER_NAME} -c etcd etcd-0 -- etcdctl --cacert=/etc/etcd/tls/etcd-ca/ca.crt --cert=/etc/etcd/tls/client/etcd-client.crt --key=/etc/etcd/tls/client/etcd-client.key endpoint health
   - Check all members are healthy
   - Note any latency warnings

3. Check etcd metrics:
   - Endpoint status: oc exec -n clusters-${HOSTED_CLUSTER_NAME} -c etcd etcd-0 -- etcdctl --cacert=/etc/etcd/tls/etcd-ca/ca.crt --cert=/etc/etcd/tls/client/etcd-client.crt --key=/etc/etcd/tls/client/etcd-client.key endpoint status --write-out=table
   - Look for: DB size, leader changes, send/receive errors

4. Analyze etcd logs:
   - Run: oc logs -n clusters-${HOSTED_CLUSTER_NAME} etcd-0 -c etcd --tail=100
   - Look for: slow requests, leader elections, compaction warnings
   - Check for "took too long" messages indicating latency issues

5. Resource utilization:
   - Check CPU/memory: oc top pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=etcd
   - Verify etcd has sufficient resources allocated
   - Check if hitting resource limits

6. Storage performance:
   - Check PVC status: oc get pvc -n clusters-${HOSTED_CLUSTER_NAME} -l app=etcd
   - Verify storage backend performance
   - Look for I/O latency issues

7. Database size and fragmentation:
   - Check if database size is approaching limits
   - Determine if defragmentation is needed
   - Review revision and compaction status

8. Network latency between members:
   - Check for network issues between etcd pods
   - Verify no packet loss or high latency

9. Recent configuration changes:
   - Check for recent updates to etcd configuration
   - Review any recent scaling operations
   - Look for operator interventions

Performance optimization recommendations:
- If high latency detected, provide tuning parameters
- If database is large, recommend compaction/defragmentation steps
- If resource constrained, suggest resource increases
- If leader elections frequent, identify stability issues

Provide actionable output with:
- Current performance metrics
- Identified bottlenecks
- Immediate optimization steps
- Long-term improvements
- Monitoring recommendations