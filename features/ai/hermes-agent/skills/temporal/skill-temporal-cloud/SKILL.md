---
name: temporal-cloud
description: Fix Temporal Cloud connection, auth, and config problems. Use when users hit login failures, can't connect to Cloud, get x509/TLS errors, have namespace or endpoint mismatches, paste broken SDK connection snippets, are confused about which endpoint to use, see "no pollers" or RESOURCE_EXHAUSTED, struggle with PrivateLink/PSC, or need help setting up a new namespace. Also use for HA namespace failover and DNS issues. Not for worker performance tuning or scaling.
---

# Temporal Cloud Skill

Help users diagnose and resolve Temporal Cloud connectivity, authentication, and configuration issues using tcld and temporal CLI.

## Core Philosophy

Cloud issues are frustrating because they sit at the intersection of configuration, networking, authentication, and Temporal-specific code. Most problems fall into predictable patterns. This skill provides systematic diagnosis to quickly identify root causes and prescribe fixes.

**References:**
- See `references/cloud-troubleshooting-reference.md` for full CLI command reference and error codes
- See `references/common-scenarios.md` for step-by-step setup walkthroughs
- [Environment configuration docs](https://docs.temporal.io/develop/environment-configuration) - SDK setup for connecting to Cloud
- [HA namespace connectivity](https://docs.temporal.io/cloud/high-availability/ha-connectivity) - multi-region endpoint and DNS setup
- [Dev Success troubleshooting guide](https://github.com/temporalio/dev-success/blob/main/troubleshooting-connection-issues-to-temporal-cloud.md) - companion connection troubleshooting guide

**Out of scope:** Worker performance tuning, scaling, metrics interpretation, SDK-specific config, deployment patterns. Those topics are covered by separate worker-focused skills.

## Issue Classification

| Category | Key Symptoms | First Check |
|----------|--------------|-------------|
| **tcld Login** | login failed, token refresh failed, wrong account | `tcld account get` |
| **Connection/Auth** | can't connect, access denied, handshake failures | Endpoint format + DNS + port connectivity |
| **Ambiguous Runtime Errors** | `context deadline exceeded`, `workflow is busy` | Identify the operation and layer first |
| **mTLS/Certs** | x509 errors, unknown authority, expired | `openssl x509 -enddate` |
| **Namespace** | namespace not found, SNI mismatch | Namespace name format |
| **HA / Failover** | Failover not working, wrong region, DNS stale | DNS CNAME resolution |
| **Worker** | Tasks not picked up, stale connections | `temporal task-queue describe` |
| **Private Connectivity** | PrivateLink/PSC errors | VPC endpoint status |
| **Rate Limiting** | RESOURCE_EXHAUSTED | APS limits |

## The Process

### Step 1: Identify the Category

Ask the user:
- **What's the exact error message?** (copy-paste if possible)
- **What are you trying to do?** (tcld command, starting workers, running workflows)
- **What changed recently?** (new certs, new namespace, new region)

### Step 2: Gather Context

**For SDK/client snippet reviews:**
- Which auth method are you using: API key or mTLS?
- Which SDK and version are you using?
- What exact `HostPort` / address are you using?
- What exact Namespace are you using?
- Is this SDK code, `temporal` CLI, or `tcld`?

**For tcld issues:**
- Can you run `tcld account get`?
- Multiple Temporal accounts?

**For connection issues:**
- What's your exact address / `HostPort`?
- Using mTLS or API keys?
- Which SDK and version are you using?
- Any firewall/proxy between you and Cloud?

**For ambiguous runtime errors:**
- Where exactly do you see the error: workflow start, signal/update, polling, querying, logs?
- Is this happening before work starts, while polling, or while workflow code is already running?
- Are pollers present on the relevant task queue?
- Did this start after a traffic spike, deploy, or config change?

**For certificate issues:**
- When were certs generated?
- What CA was used?
- Is CA uploaded to namespace?

**For worker issues:**
- Are workers running? How many?
- What does `temporal task-queue describe` show?
- Any errors in worker logs?

### Step 3: Apply Decision Tree

Use the appropriate decision tree based on category (see below).

### Step 4: Provide Fix

Give specific commands to resolve the issue, with verification steps.

Always include a confidence score for the proposed diagnosis or fix:
- `Confidence: 9-10/10` when the symptom, operation, and confirming signals line up cleanly
- `Confidence: 6-8/10` when the evidence is good but one plausible alternative remains
- `Confidence: 1-5/10` when the issue is still ambiguous and the "fix" is really the next discriminating check

If the problem is ambiguous, say so explicitly and keep the recommendation scoped to the next check rather than presenting a speculative root cause as settled.

## Decision Trees

### tcld Login Issues

```
Symptom: tcld login not working
│
├─ Can `tcld account get` run?
│  ├─ Yes → Login is valid; continue with account verification
│  └─ No → Run `tcld login`
│
├─ Token refresh failed?
│  └─ tcld logout && tcld login
│
├─ Wrong organization/account?
│  ├─ tcld account get
│  └─ Verify the expected namespace appears in `tcld namespace list`
│
└─ "unauthorized" or auth errors?
   └─ tcld logout && tcld login
```

### Connection Failures

**Docs:** [Environment configuration](https://docs.temporal.io/develop/environment-configuration) - SDK connection options

**Endpoint check before network debugging:**

| Use case | Recommended endpoint | Notes |
|----------|---------------------|-------|
| Workers & clients (all auth) | `<namespace>.<account>.tmprl.cloud:7233` | **Namespace Endpoint** - works for both mTLS and API key auth. Recommended for all namespaces. |
| Multi-region HA (advanced) | `<region>.<cloud_provider>.api.temporal.io:7233` | Regional Endpoint - only needed for advanced HA routing. See [namespace access docs](https://docs.temporal.io/cloud/namespaces#access-namespaces). |
| tcld / Cloud Ops API | `saas-api.tmprl.cloud` | Control plane |

**Exception:** Namespaces using Flexible Auth (pre-release) cannot use Namespace Endpoints yet.

```
Symptom: Can't connect to Temporal Cloud
│
├─ Check: Using Namespace Endpoint?
│  ├─ Using regional endpoint (`*.api.temporal.io`) without HA need?
│  │  └─ Switch to Namespace Endpoint (`<ns>.<acct>.tmprl.cloud:7233`)
│  ├─ Using old/stale endpoint format?
│  │  └─ Switch to Namespace Endpoint
│  └─ Endpoint looks correct → Continue
│
├─ Check: DNS resolution
│  └─ nslookup <host-from-address>
│     ├─ Fails → DNS issue (check network, VPN)
│     └─ Succeeds → Continue
│
├─ Check: Port connectivity
│  └─ nc -zv <host-from-address> 7233
│     ├─ Fails → Firewall blocking port 7233
│     └─ Succeeds → Continue
│
├─ Check: TLS handshake
│  └─ openssl s_client -connect <address>
│     ├─ Fails → Certificate issue (see mTLS tree)
│     └─ Succeeds → Continue
│
└─ Check: Temporal CLI test
   └─ temporal workflow list --limit 1 --address ...
      ├─ PERMISSION_DENIED → Check namespace name format
      ├─ UNAUTHENTICATED → Certificate not accepted
      └─ Works → Connection OK, issue elsewhere
```

### Ambiguous Runtime Errors

Do not assume these are pure connectivity failures. Classify them by operation first.

| Error text | Common interpretations | First discriminator |
|------------|------------------------|---------------------|
| `context deadline exceeded` | wrong endpoint, network timeout, oversized payload, blocked execution path, client-side timeout | Where in the flow does it occur? |
| `workflow is busy` / `RESOURCE_EXHAUSTED: Workflow is busy` | operation-level contention, workload pressure, confusing user-facing error semantics | Which operation returned it? |
| `no pollers` | no connected workers, workers present but misconfigured, stale/misleading metrics | Does `temporal task-queue describe` show pollers? |

Use this decision sequence:

```
Symptom: ambiguous runtime error
│
├─ Check: Which operation returned the error?
│  ├─ start / signal / update / query request
│  ├─ poll loop / worker logs
│  └─ UI / metrics only
│
├─ Check: Is work reaching a task queue?
│  ├─ No pollers listed
│  │  └─ Treat as worker connectivity / config until proven otherwise
│  ├─ Pollers listed, backlog growing
│  │  └─ Worker capacity / tuning issue (out of scope for this skill)
│  └─ Pollers listed, no backlog issue
│     └─ Continue
│
├─ For `context deadline exceeded`
│  ├─ Happens before any work starts
│  │  └─ Check endpoint format, auth, proxy, DNS, firewall
│  ├─ Happens on workflow start with large payloads
│  │  └─ Consider payload size / client timeout path
│  └─ Happens during local execution / queries
│     └─ Consider blocked execution path, local activity, or client-side timeout
│
└─ For `workflow is busy`
   ├─ Identify exact API / operation
   ├─ Check whether user is conflating this with a generic workflow failure
   └─ Explain that the error class is operation-specific before prescribing fixes
```

If the operation and surrounding signals still do not make the error interpretable, label it as ambiguous and gather more context before prescribing a fix.

When responding, attach a confidence score from 1-10 to the proposed diagnosis or next step. Ambiguous cases should carry a low-confidence score and a narrow next check rather than a broad claimed fix.

### SDK Snippet Review

When the user pastes SDK config, validate the config itself before suggesting lower-level networking checks.

**Review in this order:**
1. Auth method: API key vs mTLS
2. Address / `HostPort`: should be Namespace Endpoint (`<ns>.<acct>.tmprl.cloud:7233`) for most cases
3. Namespace: full Cloud namespace format (`<namespace>.<account-id>`)
4. TLS config: empty `tls.Config{}` is normal for API key auth; client cert/key required for mTLS
5. Environment config: prefer `TEMPORAL_ADDRESS`, `TEMPORAL_NAMESPACE`, `TEMPORAL_API_KEY`, `TEMPORAL_TLS_CLIENT_CERT_PATH`, `TEMPORAL_TLS_CLIENT_KEY_PATH`

**Common snippet diagnoses:**
- Using regional endpoint (`*.api.temporal.io`) when Namespace Endpoint would work → simplify to `<ns>.<acct>.tmprl.cloud:7233`
- Empty `HostPort` + Cloud namespace/auth → missing explicit Cloud endpoint
- API key without TLS enabled by the SDK/runtime → check SDK-specific Cloud guidance
- Old endpoint format (stale docs/examples) → update to current Namespace Endpoint

If the snippet is wrong, fix that first. Do not lead with DNS/TLS debugging until the endpoint and namespace are plausible.

### Certificate Errors

```
Symptom: x509 certificate errors
│
├─ "certificate signed by unknown authority"
│  ├─ Is CA uploaded to namespace?
│  │  └─ tcld namespace accepted-client-ca list --namespace <ns>
│  │     ├─ CA not listed → Add it:
│  │     │  tcld namespace accepted-client-ca add \
│  │     │    --namespace <ns> --ca-certificate-file ca.pem
│  │     └─ CA listed → Cert not signed by that CA
│  │        └─ Verify: openssl verify -CAfile ca.pem client.pem
│  │
│  └─ Self-signed cert without CA?
│     └─ Must use CA-signed certs for Cloud
│
├─ "certificate has expired"
│  ├─ Check expiry: openssl x509 -enddate -noout -in cert.pem
│  └─ Generate new cert:
│     tcld generate-certificates end-entity-certificate \
│       --organization <org> --validity-period 365d \
│       --ca-certificate-file ca.pem --ca-key-file ca.key \
│       --certificate-file client.pem --key-file client.key
│
├─ "private key does not match"
│  └─ Wrong key file - verify match:
│     openssl x509 -modulus -noout -in cert.pem | md5
│     openssl rsa -modulus -noout -in key.pem | md5
│
└─ "bad certificate" from server
   └─ Server rejected cert - CA not in accepted list
      └─ tcld namespace accepted-client-ca list --namespace <ns>
```

### Namespace Issues

```
Symptom: namespace not found or access denied
│
├─ Check: Namespace name format
│  ├─ Format: <namespace-name>.<account-id>
│  ├─ Example: my-namespace.a1b2c3
│  └─ Wrong format → Use full namespace name
│
├─ Check: Namespace exists
│  └─ tcld namespace list
│     └─ Not listed → Wrong account, or namespace not created
│
├─ Check: Address format
│  ├─ Namespace Endpoint (recommended): <namespace>.<account>.tmprl.cloud:7233
│  ├─ Regional Endpoint (HA only): <region>.<cloud_provider>.api.temporal.io:7233
│  └─ Using wrong or stale endpoint? → switch to Namespace Endpoint
│
└─ Check: User permissions
   └─ tcld user list
      └─ Verify user has access to namespace
```

### Worker Issues

This skill diagnoses **Cloud connectivity issues** for workers. Worker performance tuning, scaling, and deployment patterns are out of scope.

**Docs:** [Environment configuration](https://docs.temporal.io/develop/environment-configuration) - SDK connection setup

```
Symptom: Workers not picking up tasks
│
├─ Check: Are workers running?
│  └─ Verify worker process is up, check logs for errors
│
├─ Check: Task queue status
│  └─ temporal task-queue describe --task-queue <queue>
│     ├─ No pollers listed → Workers not connected (Cloud issue)
│     │  ├─ Check task queue name matches
│     │  ├─ Check namespace in worker config
│     │  ├─ Verify SDK connection options (see env config docs)
│     │  └─ Check for connection errors in logs
│     │
│     │  Note: if only metrics or dashboards say "no pollers", verify with CLI or another direct surface before concluding workers are absent.
│     │
│     ├─ Pollers listed but backlog growing
│     │  └─ NOT a Cloud issue (worker scaling/tuning problem)
│     │
│     └─ Pollers listed, no backlog
│        └─ Workers healthy, issue is elsewhere
│
├─ Check: DNS caching (common in K8s)
│  └─ Stale DNS can cause workers to connect to wrong endpoint
│     └─ Restart workers to refresh DNS
│
└─ Check: Rate limiting
   └─ RESOURCE_EXHAUSTED in logs?
      └─ See Rate Limiting section
```

**Scope clarification:**

| Issue Type | In Scope? |
|------------|-----------|
| tcld login, certs, namespace, private connectivity | Yes |
| Worker scaling, metrics, tuning, deployment | No |
| "Workers not picking up tasks" | Yes - diagnose, hand off if not a Cloud issue |

### HA Namespace Connectivity

**Docs:** [HA namespace connectivity](https://docs.temporal.io/cloud/high-availability/ha-connectivity)

HA (multi-region) namespaces use a hierarchical DNS structure:
- Namespace endpoint: `<ns>.<acct>.tmprl.cloud` (CNAME to active region)
- Regional endpoint: `<region>.region.tmprl.cloud`
- During failover, CNAME switches regions (15s TTL, ~30s convergence)

```
Symptom: HA namespace connectivity or failover issues
│
├─ Check: DNS resolution
│  └─ nslookup <namespace>.tmprl.cloud
│     ├─ Should return CNAME → <region>.region.tmprl.cloud
│     └─ Then resolve to IP address
│
├─ Symptom: Clients not failing over
│  ├─ Check: DNS caching
│  │  ├─ TTL is 15s - clients should converge within 30s
│  │  ├─ Some DNS resolvers cache longer
│  │  └─ Fix: Restart workers to refresh DNS
│  │
│  └─ Check: SDK connection caching
│     └─ Some SDKs cache connections - may need restart
│
├─ Symptom: PrivateLink not working after failover
│  ├─ Check: Regional DNS override configured?
│  │  └─ Need Route 53 private hosted zone for region.tmprl.cloud
│  │     mapping regional endpoints to VPC endpoint IPs
│  │
│  └─ Check: Inter-region connectivity
│     └─ Workers need Transit Gateway or VPC Peering to reach
│        VPC endpoints in both regions
│
├─ Symptom: GCP Private Service Connect not working
│  └─ NOT SUPPORTED: Private connectivity not yet offered for
│     GCP Multi-region Namespaces
│
└─ Symptom: sa-east-1 region issues
   └─ NOT SUPPORTED: sa-east-1 not available for Multi-region namespaces (because there are no other regions on the continent)
```

**Worker placement for HA:**
- Option A: Run workers in both regions continuously
- Option B: Single region + Transit Gateway/VPC Peering for failover access

### Private Connectivity Issues

```
Symptom: PrivateLink or Private Service Connect not working
│
├─ AWS PrivateLink
│  ├─ Check: VPC endpoint status
│  │  └─ AWS Console → VPC → Endpoints → Status = available
│  │
│  ├─ Check: Security groups
│  │  └─ Allow outbound to endpoint on port 7233
│  │
│  ├─ Check: DNS resolution
│  │  └─ Should resolve to private IP (10.x or 172.x)
│  │
│  └─ Check: Connectivity rules
│     ├─ tcld connectivity-rule list --namespace <ns>
│     └─ If needed, attach rules with:
│        tcld namespace set-connectivity-rules --namespace <ns> --connectivity-rule-ids <id>
│
├─ GCP Private Service Connect
│  ├─ Check: PSC endpoint status
│  │  └─ GCP Console → Network Services → Private Service Connect
│  │
│  ├─ Check: Firewall rules
│  │  └─ Allow egress to PSC endpoint
│  │
│  └─ Check: DNS configuration
│     └─ Cloud DNS zone for tmprl.cloud pointing to PSC
│
└─ General
   └─ Verify rule details:
      tcld connectivity-rule get --connectivity-rule-id <id>
```

### Rate Limiting

```
Symptom: RESOURCE_EXHAUSTED errors
│
├─ Check: Which operation is limited?
│  └─ Error message indicates operation type
│
├─ "namespace write ops" exceeded
│  ├─ Too many workflow starts
│  ├─ Too many signals/updates
│  └─ Fix: Add backoff, batch operations
│
├─ "namespace read ops" exceeded
│  ├─ Too many list/query operations
│  └─ Fix: Add caching, reduce polling frequency
│
└─ Poll operations rate limited
   ├─ Too many pollers across workers
   └─ Fix: Reduce MaxConcurrentPollers settings
```

## Common Scenarios

See `references/common-scenarios.md` for step-by-step walkthroughs:
- API key connectivity setup
- New namespace setup (mTLS)
- Certificate rotation
- Switching from mTLS to API keys

## Common Pitfalls

| Pitfall | Why It Happens | Fix |
|---------|----------------|-----|
| Wrong namespace format | Using short name instead of `name.account-id` | Use full namespace from `tcld namespace list` |
| Self-signed certs | Trying to use self-signed without CA | Generate CA first, sign certs with it, upload CA |
| Regional endpoint when unnecessary | Using `*.api.temporal.io` when Namespace Endpoint works | Switch to `<namespace>.<account>.tmprl.cloud:7233` |
| Old endpoint docs | Following stale examples from before Namespace Endpoints were universal | Use Namespace Endpoint: `<ns>.<acct>.tmprl.cloud:7233` |
| Expired certs | Not monitoring expiry | Set up alerts, rotate before expiry |
| tcld wrong account | Logged into different org | Use `tcld account get`, then verify the namespace in `tcld namespace list` |
| Stale tcld login | Cached auth state is no longer valid | `tcld logout && tcld login` |
| DNS caching | K8s pods caching old DNS | Restart pods after endpoint changes |
| Missing port | Firewall blocks 7233 | Ensure egress allowed on port 7233 |

## Tips

- **Always get the exact error message** - Copy-paste, don't paraphrase
- **Check the simple things first** - DNS, port connectivity, cert expiry
- **Use Namespace Endpoint by default** - `<ns>.<acct>.tmprl.cloud:7233` works for both mTLS and API key auth
- **Use openssl for cert issues** - It gives clearer error messages than SDKs
- **tcld account get is your friend** - Shows the current account context
- **Namespace names are case-sensitive** - Match exactly
- **API keys are easier than mTLS** - Consider for simpler setups
- **Point users to env config docs** - [Environment configuration](https://docs.temporal.io/develop/environment-configuration) covers all SDK connection options
