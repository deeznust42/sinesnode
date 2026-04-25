#!/usr/bin/env bash
# Set up a local SSH tunnel from your laptop to a running llama-server SLURM job.
# Reads ~/.llama-server.info on the cluster to discover which compute node + port,
# then forwards localhost:<LOCAL_PORT> through the master to that node.
#
# Usage (on your laptop):
#   bash scripts/connect-llm.sh           # forwards to localhost:8080
#   LOCAL_PORT=9000 bash scripts/connect-llm.sh
#
# Leave the resulting ssh process running. Open http://localhost:8080 in a browser
# or point an OpenAI-compatible client at http://localhost:8080/v1.

set -euo pipefail

REMOTE="${REMOTE:-sines}"
LOCAL_PORT="${LOCAL_PORT:-8080}"

INFO=$(ssh "$REMOTE" 'cat ~/.llama-server.info 2>/dev/null') || {
    echo "Could not read ~/.llama-server.info on $REMOTE."
    echo "Has 'sbatch slurm/llama-server.sbatch' been submitted and started running?"
    echo "Check on the cluster with:  squeue --me"
    exit 1
}

REMOTE_HOST=$(echo "$INFO" | awk -F= '/^host=/{print $2}')
REMOTE_PORT=$(echo "$INFO" | awk -F= '/^port=/{print $2}')
JOB_ID=$(    echo "$INFO" | awk -F= '/^job=/ {print $2}')

if [ -z "${REMOTE_HOST:-}" ] || [ -z "${REMOTE_PORT:-}" ]; then
    echo "Malformed info file:"; echo "$INFO"; exit 1
fi

# Confirm the job is actually still running.
STATE=$(ssh "$REMOTE" "squeue -j ${JOB_ID} -h -o %T" 2>/dev/null || true)
if [ "$STATE" != "RUNNING" ]; then
    echo "Job ${JOB_ID} state is '${STATE:-unknown}', not RUNNING. Tunnel won't reach the server."
    echo "Re-submit with:  sbatch slurm/llama-server.sbatch"
    exit 1
fi

echo "Tunneling localhost:${LOCAL_PORT}  →  ${REMOTE_HOST}:${REMOTE_PORT}  (job ${JOB_ID})"
echo "Open http://localhost:${LOCAL_PORT}   |   API: http://localhost:${LOCAL_PORT}/v1"
echo "Ctrl-C to disconnect."

exec ssh -N \
    -L "${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT}" \
    "$REMOTE"
