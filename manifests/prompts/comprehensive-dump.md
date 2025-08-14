# Comprehensive Diagnostic Data Collection

**Cluster:** `${HOSTED_CLUSTER_NAME}`  
**Type:** Full Diagnostic Dump  
**Purpose:** Initial investigation baseline

---

## 📊 Data Collection Steps

### Step 1: Execute HyperShift Dump

Run the comprehensive dump command:

```bash
CLUSTERNAME="${HOSTED_CLUSTER_NAME}"
CLUSTERNS="clusters"
ARTIFACT_DIR="/tmp/dump-${CLUSTERNAME}-$(date +%Y%m%d-%H%M%S)"

hypershift dump cluster \
    --name "${CLUSTERNAME}" \
    --namespace "${CLUSTERNS}" \
    --dump-guest-cluster \
    --artifact-dir "${ARTIFACT_DIR}"
```

### Step 2: Quick Status Check (While Dump Runs)

```bash
# HostedCluster status
oc get hostedcluster -n clusters ${HOSTED_CLUSTER_NAME}

# NodePool status
oc get nodepool -n clusters ${HOSTED_CLUSTER_NAME}

# Control plane pods
oc get pods -n clusters-${HOSTED_CLUSTER_NAME}
```

### Step 3: Analyze Dump Output

Review the collected data for:
- ⚠️ ERROR or FATAL messages
- 🔍 Must-gather critical issues
- ❌ Failed collection components

### Step 4: Additional Context Collection

If dump reveals issues, gather:

```bash
# Recent events (last 50)
oc get events -n clusters-${HOSTED_CLUSTER_NAME} \
    --sort-by='.lastTimestamp' | head -50

# Resource utilization
oc top pods -n clusters-${HOSTED_CLUSTER_NAME}

# Storage status
oc get pvc -n clusters-${HOSTED_CLUSTER_NAME}
```

### Step 5: Health Assessment Checklist

Evaluate from dump data:
- ✅ Control plane component status
- ✅ etcd health metrics
- ✅ API server responsiveness
- ✅ Operator status
- ✅ Node readiness

### Step 6: Pattern Recognition

Identify common issues:
- 🔄 Recurring errors across components
- 📈 Resource constraints
- 🌐 Network connectivity problems
- ⚙️ Configuration inconsistencies

---

## 📝 Required Output

Based on the comprehensive dump, provide:

### 1. Executive Summary
- Overall cluster health status
- Risk assessment (Critical/Warning/Healthy)

### 2. Critical Issues
- Immediate problems requiring action
- Impact assessment for each issue

### 3. Warning Signs
- Potential problems developing
- Preventive recommendations

### 4. Investigation Paths
- Suggested next steps based on findings
- Priority order for investigations

### 5. Deep Dive Areas
- Specific log files needing review
- Components requiring detailed analysis

---

> **Important:** This comprehensive dump is the foundation for all troubleshooting. Always start here unless there's a specific urgent issue to address.