Pause or resume HostedCluster reconciliation for ${HOSTED_CLUSTER_NAME}.
This is used for maintenance or to prevent operator interference during troubleshooting.

Current state check:

1. Check if currently paused:
   ```bash
   oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} -o json | jq '.spec.pausedUntil'
   ```
   - If null: Reconciliation is active
   - If "true": Reconciliation is paused

To PAUSE reconciliation:

2. Document current state before pausing:
   - Save current status: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} -o yaml > /tmp/hc-before-pause-${HOSTED_CLUSTER_NAME}.yaml
   - Record timestamp: echo "Paused at: $(date)" > /tmp/pause-timestamp-${HOSTED_CLUSTER_NAME}.txt

3. Pause the HostedCluster:
   ```bash
   oc patch hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} \
       --type merge -p '{"spec":{"pausedUntil":"true"}}'
   ```

4. Verify pause is active:
   - Check annotation: oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} -o json | jq '.spec.pausedUntil'
   - Verify operator logs show reconciliation stopped
   - Confirm no automatic changes are being made

5. While paused, you can:
   - Manually modify resources without operator interference
   - Perform maintenance operations
   - Troubleshoot without automatic reconciliation
   - Make configuration changes for testing

To RESUME reconciliation:

6. Before resuming, ensure:
   - Any manual changes are complete
   - System is in a stable state
   - No conflicting configurations exist

7. Resume the HostedCluster:
   ```bash
   oc patch hostedcluster -n clusters ${HOSTED_CLUSTER_NAME} \
       --type merge -p '{"spec":{"pausedUntil":null}}'
   ```

8. Monitor resumption:
   - Watch operator logs: oc logs -n hypershift deployment/hypershift-operator -f | grep ${HOSTED_CLUSTER_NAME}
   - Check for reconciliation activity
   - Verify control plane pods for any changes

9. Post-resume validation:
   - Check HostedCluster conditions: oc describe hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}
   - Verify all components are healthy
   - Check for any errors from reconciliation

10. Document changes:
    - Record what was done during pause
    - Note any issues encountered
    - Document configuration changes made

Important considerations:
- Pausing prevents automatic updates and fixes
- Extended pauses may cause drift from desired state
- Some critical operations may still occur even when paused
- Always resume reconciliation after maintenance

Provide status report:
- Current pause state
- Actions taken (pause/resume)
- Any changes made while paused
- System state after operation
- Recommendations for next steps