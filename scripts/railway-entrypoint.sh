#!/bin/bash
# Railway entrypoint: starts the Docker daemon, builds the agent image,
# then hands off to the NanoClaw Node.js app.

set -e

# ---------------------------------------------------------------------------
# 1. Start Docker daemon in the background
# ---------------------------------------------------------------------------
echo "[entrypoint] Starting Docker daemon..."

# Railway containers run without CAP_NET_ADMIN, so the iptables nf_tables
# backend fails immediately ("Could not fetch rule set generation id:
# Permission denied") even before --iptables=false takes effect.
#
# Workaround: replace iptables binaries with no-op stubs so that dockerd's
# bridge-driver registration succeeds. Agent containers run with
# --network=host (injected by container-runner.ts on Railway) so they still
# reach the internet (Anthropic API) without any bridge networking.
if [ -n "${RAILWAY_ENVIRONMENT:-}" ]; then
  echo "[entrypoint] Railway detected: stubbing iptables to bypass CAP_NET_ADMIN requirement..."
  for cmd in iptables iptables-save iptables-restore \
              ip6tables ip6tables-save ip6tables-restore \
              iptables-legacy ip6tables-legacy; do
    printf '#!/bin/sh\nexit 0\n' > /usr/local/sbin/$cmd
    chmod +x /usr/local/sbin/$cmd
  done
fi

dockerd --host unix:///var/run/docker.sock \
        --iptables=false \
        --ip6tables=false \
        --log-level error \
        &
DOCKERD_PID=$!

echo "[entrypoint] Waiting for Docker daemon to become ready..."
for i in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then
    echo "[entrypoint] Docker daemon ready (${i}s)"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "[entrypoint] ERROR: Docker daemon did not start within 60 seconds."
    exit 1
  fi
  sleep 1
done

# ---------------------------------------------------------------------------
# 2. Build the nanoclaw-agent container image IN THE BACKGROUND so that
#    Node.js can start immediately and answer Railway's healthcheck.
#    Set SKIP_CONTAINER_BUILD=1 to skip (e.g., when pulling from a registry).
# ---------------------------------------------------------------------------
if [ -z "$SKIP_CONTAINER_BUILD" ]; then
  echo "[entrypoint] Building nanoclaw-agent image in background (this may take a few minutes on first deploy)..."
  (cd /app && ./container/build.sh && echo "[entrypoint] Agent image built successfully.") &
else
  echo "[entrypoint] Skipping container build (SKIP_CONTAINER_BUILD is set)."
fi

# ---------------------------------------------------------------------------
# 3. Start the NanoClaw Node.js application immediately.
#    The /health endpoint becomes available right away; agent tasks that
#    arrive before the image is ready will fail gracefully and can be retried.
# ---------------------------------------------------------------------------
echo "[entrypoint] Starting NanoClaw..."
cd /app
exec node dist/index.js
