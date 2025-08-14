Scale NodePool for cluster ${HOSTED_CLUSTER_NAME}.
NodePool name: ${NODEPOOL_NAME}, Target replicas: ${TARGET_REPLICAS}

Pre-scaling assessment:

1. Check current NodePool status:
   - Run: oc get nodepool -n clusters ${NODEPOOL_NAME}
   - Note current replicas and ready count
   - Run: oc describe nodepool -n clusters ${NODEPOOL_NAME}
   - Check for any existing issues or conditions

2. Verify cluster capacity:
   - Check current nodes: oc get nodes -o wide
   - Review resource utilization: oc adm top nodes
   - Ensure infrastructure can support scaling

3. Check Machine status:
   - Current machines: oc get machines -n clusters-${HOSTED_CLUSTER_NAME}
   - Verify no machines are in Failed state
   - Check for any pending provisions

Execute scaling operation:

4. Scale the NodePool:
   ```bash
   oc scale nodepool -n clusters ${NODEPOOL_NAME} --replicas=${TARGET_REPLICAS}
   ```

5. Monitor scaling progress:
   - Watch NodePool: oc get nodepool -n clusters ${NODEPOOL_NAME} -w
   - Monitor machines: oc get machines -n clusters-${HOSTED_CLUSTER_NAME} -w
   - Track events: oc get events -n clusters-${HOSTED_CLUSTER_NAME} --watch

6. For scale-up operations, monitor:
   - New machine creation
   - Infrastructure provisioning
   - Node joining the cluster
   - Node becoming Ready

7. For scale-down operations, monitor:
   - Node draining process
   - Pod evacuation
   - Machine deletion
   - Infrastructure cleanup

8. Validate scaling completion:
   - Verify NodePool shows correct replicas
   - All nodes are Ready: oc get nodes
   - No pending machines: oc get machines -n clusters-${HOSTED_CLUSTER_NAME}

9. Post-scaling health check:
   - Check workload distribution
   - Verify no pods are pending due to insufficient resources
   - Check cluster autoscaler if configured

10. If scaling fails:
    - Check infrastructure quotas
    - Review CAPI provider logs
    - Verify cloud credentials
    - Check for network issues
    - Review any error events

For forced node replacement (rolling update):

11. Trigger replacement if needed:
    ```bash
    oc patch nodepool -n clusters ${NODEPOOL_NAME} \
        --type merge -p '{"spec":{"management":{"replace":{"strategy":"RollingUpdate"}}}}'
    ```

12. Monitor replacement:
    - Watch old nodes drain
    - Verify new nodes join
    - Ensure workloads migrate successfully

Provide scaling report:
- Initial state (replicas before)
- Target state (replicas after)
- Scaling duration
- Any issues encountered
- Current cluster capacity
- Recommendations for workload distribution