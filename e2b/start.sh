#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DONNA Goose E2B Sandbox Startup Script
#
# Environment variables injected by the cloud DONNA API:
#   GOOSE_PROVIDER          — openrouter
#   GOOSE_MODEL             — qwen/qwen3.6-plus
#   OPENROUTER_API_KEY      — caller's or shared pool key
#   HAI_API_KEY             — (optional) H Company key for Holo3 delegation
#   DONNA_MCP_URL           — https://app.bemdonna.com/api/v1/mcp
#   DONNA_COGNITO_TOKEN     — Bearer token to authenticate with cloud DONNA
#   GOOSE_TELEMETRY_OFF     — 1
# ============================================================

GOOSE_BIN="/opt/goose/target/release/goose-server"
GOOSE_PORT="${GOOSE_PORT:-3000}"
SECRET_KEY="$(openssl rand -hex 32)"
CONFIG_DIR="/root/.config/goose"

echo "[start.sh] Starting Goose E2B sandbox..."
echo "[start.sh] Provider: ${GOOSE_PROVIDER}, Model: ${GOOSE_MODEL}"

mkdir -p "${CONFIG_DIR}"

# Write goose config
cat > "${CONFIG_DIR}/config.yaml" <<GOOSE_CONFIG
GOOSE_PROVIDER: "${GOOSE_PROVIDER:-openrouter}"
GOOSE_MODEL: "${GOOSE_MODEL:-qwen/qwen3.6-plus}"
GOOSE_TELEMETRY_OFF: "1"
GOOSE_CONFIG

# Start goose-server
export GOOSE_SERVER_PORT="${GOOSE_PORT}"
export GOOSE_SERVER_SECRET_KEY="${SECRET_KEY}"
"${GOOSE_BIN}" &
GOOSE_PID=$!

# Wait for goose-server to be ready
echo "[start.sh] Waiting for goose-server on port ${GOOSE_PORT}..."
for i in $(seq 1 30); do
    if curl -sf "http://localhost:${GOOSE_PORT}/status" > /dev/null 2>&1; then
        echo "[start.sh] goose-server is up."
        break
    fi
    sleep 1
done

# Register "donna" MCP extension — the bridge between Goose and Local Donna.
# This is the ONLY MCP extension Goose gets. Goose never calls cloud Donna directly.
if [[ -n "${DONNA_BRIDGE_URL:-}" ]]; then
    echo "[start.sh] Registering donna MCP extension..."
    curl -sf -X POST "http://localhost:${GOOSE_PORT}/config/extensions" \
        -H "X-Secret-Key: ${SECRET_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"donna\",
            \"enabled\": true,
            \"config\": {
                \"type\": \"streamable_http\",
                \"name\": \"donna\",
                \"uri\": \"${DONNA_BRIDGE_URL}/mcp\",
                \"timeout\": 120,
                \"headers\": {
                    \"X-Bridge-Token\": \"${DONNA_BRIDGE_TOKEN}\"
                }
            }
        }" && echo "[start.sh] donna extension registered." || \
        echo "[start.sh] WARNING: Failed to register donna extension."
fi

echo "[start.sh] Goose is ready. PID=${GOOSE_PID}"

# Keep the sandbox alive by waiting on goose-server
wait "${GOOSE_PID}"
