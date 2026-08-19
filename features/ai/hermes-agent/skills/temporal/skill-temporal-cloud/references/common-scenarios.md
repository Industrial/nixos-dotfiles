# Common Scenarios

Step-by-step walkthroughs for common Temporal Cloud setup and configuration tasks.

## API Key Connectivity

User is connecting to Temporal Cloud with an API key.

**Checklist:**
1. Use the full namespace name (`<name>.<account-id>`)
2. Use the Namespace Endpoint (`<ns>.<acct>.tmprl.cloud:7233`) - works for all auth methods
3. Keep credentials in environment variables where possible
4. Verify with `temporal workflow list`

```bash
export TEMPORAL_NAMESPACE="my-ns.abc123"
export TEMPORAL_ADDRESS="my-ns.abc123.tmprl.cloud:7233"
export TEMPORAL_API_KEY="<api-key>"

temporal workflow list --limit 1 \
  --address "$TEMPORAL_ADDRESS" \
  --namespace "$TEMPORAL_NAMESPACE" \
  --api-key "$TEMPORAL_API_KEY"
```

## New Namespace Setup

User is setting up connection to a new namespace for the first time.

**Docs:** [Environment configuration](https://docs.temporal.io/develop/environment-configuration) - full SDK setup guide

**Checklist:**
1. Get namespace name (full format with account ID)
2. Generate or obtain certificates
3. Upload CA to namespace
4. Test connection with temporal CLI
5. Configure workers using [environment configuration docs](https://docs.temporal.io/develop/environment-configuration)

```bash
# 1. Verify namespace exists and get full name
tcld namespace list

# 2. Generate certs (if needed)
tcld generate-certificates certificate-authority-certificate \
  --organization mycompany \
  --validity-period 365d \
  --ca-certificate-file certs/ca.pem \
  --ca-key-file certs/ca.key
tcld generate-certificates end-entity-certificate \
  --organization mycompany \
  --validity-period 365d \
  --ca-certificate-file certs/ca.pem \
  --ca-key-file certs/ca.key \
  --certificate-file certs/client.pem \
  --key-file certs/client.key

# 3. Upload CA
tcld namespace accepted-client-ca add \
  --namespace my-ns.abc123 \
  --ca-certificate-file certs/ca.pem

# 4. Test connection
temporal workflow list --limit 1 \
  --address my-ns.abc123.tmprl.cloud:7233 \
  --namespace my-ns.abc123 \
  --tls-cert-path certs/client.pem \
  --tls-key-path certs/client.key
```

## Certificate Rotation

Rotate certs before expiry. If rotating CA, add new CA first, deploy new certs, then remove old CA.

```bash
# Check expiry
openssl x509 -enddate -noout -in client.pem

# Generate new leaf cert (same CA)
tcld generate-certificates end-entity-certificate \
  --organization mycompany \
  --validity-period 365d \
  --ca-certificate-file ca.pem \
  --ca-key-file ca.key \
  --certificate-file new-certs/client.pem \
  --key-file new-certs/client.key

# If rotating CA too:
# 1. Generate new CA
tcld generate-certificates certificate-authority-certificate \
  --organization mycompany \
  --validity-period 365d \
  --ca-certificate-file new-ca/ca.pem \
  --ca-key-file new-ca/ca.key

# 2. Add new CA to namespace (keep old one temporarily)
tcld namespace accepted-client-ca add \
  --namespace my-ns.abc123 \
  --ca-certificate-file new-ca/ca.pem

# 3. Deploy new certs to workers

# 4. Remove old CA
tcld namespace accepted-client-ca list --namespace my-ns.abc123
tcld namespace accepted-client-ca remove \
  --namespace my-ns.abc123 \
  --fp <old-ca-fingerprint>
```

## Switching from mTLS to API Keys

User wants to use API keys instead of certificates.

```bash
# 1. Create service account
tcld service-account create \
  --name worker-sa \
  --description "Service account for workers"

# 2. Create API key
tcld apikey create \
  --service-account-id <sa-id> \
  --description "Worker API key"

# 3. Test with temporal CLI (same Namespace Endpoint, just swap auth)
temporal workflow list --limit 1 \
  --address my-ns.abc123.tmprl.cloud:7233 \
  --namespace my-ns.abc123 \
  --api-key <api-key>

# 4. Update worker config to use API key instead of certs
```
