Execute emergency control plane restart for cluster ${HOSTED_CLUSTER_NAME}.
This is an emergency procedure to recover from control plane issues.

WARNING: This will restart all control plane components. Ensure this is necessary before proceeding.

Pre-restart checks:

1. Verify current state:
   - Check HostedCluster: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Document current pod states: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -o wide > /tmp/before-restart-${HOSTED_CLUSTER_NAME}.txt
   - Save recent events: oc get events -n clusters-${HOSTED_CLUSTER_NAME} --sort-by='.lastTimestamp' > /tmp/events-before-restart-${HOSTED_CLUSTER_NAME}.txt

2. Check for active operations:
   - Verify no upgrade in progress
   - Check for ongoing scaling operations
   - Ensure no critical workloads are being processed

Execute restart:

3. Annotate HostedCluster to trigger restart:
   ```bash
   oc annotate hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} \
       hypershift.openshift.io/restart-date="$(date)" --overwrite
   ```

4. Monitor restart progress:
   - Watch pods: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -w
   - Monitor for all pods to restart (check AGE column)
   - Verify pods come back to Running state

5. Validate component health after restart:
   - API Server: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-apiserver
   - etcd: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=etcd
   - Controller Manager: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-controller-manager
   - Scheduler: oc get pods -n clusters-${HOSTED_CLUSTER_NAME} -l app=kube-scheduler

6. Check etcd health specifically:
   ```bash
   oc exec -n clusters-${HOSTED_CLUSTER_NAME} -c etcd etcd-0 -- etcdctl \
       --cacert=/etc/etcd/tls/etcd-ca/ca.crt \
       --cert=/etc/etcd/tls/client/etcd-client.crt \
       --key=/etc/etcd/tls/client/etcd-client.key \
       endpoint health
   ```

7. Verify API accessibility:
   - Test API response time
   - Check if kubectl/oc commands work against hosted cluster
   - Verify authentication is working

8. Post-restart validation:
   - Check HostedCluster conditions: oc describe hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Verify all conditions return to normal
   - Check for any new error events

9. If restart doesn't resolve issues:
   - Collect logs from failed components
   - Check for configuration issues
   - Consider individual component troubleshooting
   - May need to pause reconciliation for manual intervention

Document results:
- Components that successfully restarted
- Any components that failed to restart
- Current cluster state after restart
- Any persistent issues requiring further investigation
- Recommendations for root cause analysis

Note: Control plane restart is a temporary fix. Always investigate root cause after stabilization.