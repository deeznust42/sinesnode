#!/usr/bin/env bash
# One-time setup on the cluster: build llama.cpp in $HOME and download a model.
# Compiling and downloading happen via SLURM (srun) so we never abuse the master node.
#
# Usage (on master node, after probe-cluster.sh has confirmed gcc/cmake exist
# and outbound internet works):
#   bash bootstrap-llama.sh
#
# Override the default model with:
#   MODEL_URL=... MODEL_NAME=... bash bootstrap-llama.sh

set -euo pipefail

LLAMA_DIR="${LLAMA_DIR:-$HOME/llama.cpp}"
MODELS_DIR="${MODELS_DIR:-$HOME/models}"

# Default: Qwen2.5-7B-Instruct Q4_K_M GGUF (~4.7 GB, runs comfortably on CPU).
# Swap by setting MODEL_URL / MODEL_NAME env vars.
MODEL_URL="${MODEL_URL:-https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf}"
MODEL_NAME="${MODEL_NAME:-qwen2.5-7b-instruct-q4_k_m.gguf}"

# Reasonable srun budget for compile + download. Adjust if your cluster has shorter limits.
SRUN_BUILD_OPTS="${SRUN_BUILD_OPTS:---nodes=1 --cpus-per-task=8 --mem=8G --time=00:45:00}"

mkdir -p "$MODELS_DIR"

echo "==> Cloning llama.cpp (if missing)"
if [ ! -d "$LLAMA_DIR/.git" ]; then
    srun $SRUN_BUILD_OPTS bash -c "git clone --depth=1 https://github.com/ggerganov/llama.cpp '$LLAMA_DIR'"
else
    echo "    already present at $LLAMA_DIR"
fi

echo "==> Building llama.cpp on a compute node"
srun $SRUN_BUILD_OPTS bash -c "
    set -euo pipefail
    cd '$LLAMA_DIR'
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DLLAMA_NATIVE=ON
    cmake --build build -j --config Release
"

echo "==> Downloading model: $MODEL_NAME"
if [ ! -f "$MODELS_DIR/$MODEL_NAME" ]; then
    srun $SRUN_BUILD_OPTS bash -c "
        cd '$MODELS_DIR'
        curl -L --fail --retry 3 -o '$MODEL_NAME.partial' '$MODEL_URL'
        mv '$MODEL_NAME.partial' '$MODEL_NAME'
    "
else
    echo "    already present"
fi

echo
echo "Done."
echo "  llama.cpp: $LLAMA_DIR/build/bin/llama-server"
echo "  model:     $MODELS_DIR/$MODEL_NAME"
echo
echo "Next: sbatch slurm/llama-server.sbatch"
