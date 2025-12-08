#!/bin/bash
set -e

# Load environment variables
if [ -f "backend/.env" ]; then
    echo "📄 Loading configuration from backend/.env..."
    export $(grep -v '^#' backend/.env | xargs)
else
    echo "❌ backend/.env not found. Please run ./setup_env.sh first."
    exit 1
fi

PROJECT_ID=${GCP_PROJECT_ID:-$(gcloud config get-value project)}
REGION=${GCP_LOCATION:-"europe-west1"}
INSTANCE_URI="${INSTANCE_CONNECTION_NAME}"

echo "🔧 Setting up local Toolbox environment..."

# 1. Start AlloyDB Auth Proxy via Bastion (background)
echo "🔌 Starting AlloyDB Auth Proxy via Bastion..."

BASTION_NAME="search-demo-bastion"
BASTION_ZONE="${REGION}-b"

# Ensure local proxy binary exists
if [ ! -f "alloydb-auth-proxy" ]; then
    echo "   Downloading proxy binary locally..."
    wget -q https://storage.googleapis.com/alloydb-auth-proxy/v1.10.0/alloydb-auth-proxy.linux.amd64 -O alloydb-auth-proxy
    chmod +x alloydb-auth-proxy
fi

# Copy proxy to Bastion (since Bastion might not have internet)
echo "   Copying proxy to Bastion..."
# Kill existing proxy process to avoid "Text file busy" error
gcloud compute ssh $BASTION_NAME --zone $BASTION_ZONE --command "killall alloydb-auth-proxy || true" --quiet
gcloud compute scp alloydb-auth-proxy $BASTION_NAME:~/alloydb-auth-proxy --zone $BASTION_ZONE --quiet
gcloud compute ssh $BASTION_NAME --zone $BASTION_ZONE --command "chmod +x alloydb-auth-proxy"

# Start Proxy on Bastion and Tunnel
# We tunnel local 5432 -> Bastion 5432 (where proxy listens)
echo "   Establishing SSH tunnel and starting remote proxy..."
gcloud compute ssh $BASTION_NAME --zone $BASTION_ZONE \
    --command "./alloydb-auth-proxy \"$INSTANCE_URI\" --address=127.0.0.1 --port=5432" \
    -- -L 5432:127.0.0.1:5432 > proxy.log 2>&1 &
PROXY_PID=$!
echo "   Proxy/Tunnel PID: $PROXY_PID"

# Cleanup function
cleanup() {
    echo "🧹 Stopping proxy..."
    kill $PROXY_PID || true
}
trap cleanup EXIT

# Wait for proxy to start (simple sleep)
echo "⏳ Waiting for proxy to initialize..."
sleep 5

# 2. Run Toolbox
# 2. Run Toolbox
echo "📦 Running Toolbox..."
if [ ! -f "toolbox" ]; then
    echo "❌ toolbox binary not found. Downloading v0.22.0..."
    curl -L -o toolbox https://storage.googleapis.com/genai-toolbox/v0.22.0/linux/amd64/toolbox
    chmod +x toolbox
fi

# Export DB_PASSWORD for substitution in tools_local.yaml
export DB_PASSWORD=$DB_PASSWORD

./toolbox --tools_file backend/mcp_server/tools_local.yaml --ui
