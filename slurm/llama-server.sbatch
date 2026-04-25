#!/bin/bash
#SBATCH --job-name=llama-server
#SBATCH --output=%x-%j.log
#SBATCH --error=%x-%j.log
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#
# Launch llama.cpp's HTTP server on a compute node for the duration of the job.
# Submit from the cluster:
#     sbatch slurm/llama-server.sbatch
# Then on your laptop, run scripts/connect-llm.sh to tunnel a local port to it.
#
# Tweak --cpus-per-task / --mem / --time for your model size and session length.
# Override the model by editing MODEL or exporting it before sbatch.

set -euo pipefail

LLAMA_BIN="${LLAMA_BIN:-$HOME/llama.cpp/build/bin/llama-server}"
MODEL="${MODEL:-$HOME/models/qwen2.5-7b-instruct-q4_k_m.gguf}"
PORT="${PORT:-8080}"
CTX="${CTX:-4096}"

# Write the assigned compute node + port to a file so connect-llm.sh can find it.
INFO_FILE="$HOME/.llama-server.info"
echo "host=$(hostname)" >  "$INFO_FILE"
echo "port=${PORT}"     >> "$INFO_FILE"
echo "job=${SLURM_JOB_ID}" >> "$INFO_FILE"
echo "started=$(date -Iseconds)" >> "$INFO_FILE"

echo "[llama-server] node=$(hostname) port=${PORT} model=${MODEL}"
echo "[llama-server] info written to ${INFO_FILE}"

exec "$LLAMA_BIN" \
    --model      "$MODEL" \
    --ctx-size   "$CTX" \
    --threads    "${SLURM_CPUS_PER_TASK:-8}" \
    --host       0.0.0.0 \
    --port       "$PORT"
