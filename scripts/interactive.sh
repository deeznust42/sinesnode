#!/usr/bin/env bash
# Convenience: SSH to master and immediately request an interactive SLURM
# session on a compute node. Useful for quick model experiments without
# submitting a batch job.
#
# Usage (on your laptop):
#   bash scripts/interactive.sh                    # 4 CPUs, 8G, 1 hour
#   CPUS=16 MEM=32G TIME=04:00:00 bash scripts/interactive.sh

set -euo pipefail

REMOTE="${REMOTE:-sines}"
CPUS="${CPUS:-4}"
MEM="${MEM:-8G}"
TIME_LIMIT="${TIME:-01:00:00}"

exec ssh -t "$REMOTE" \
    "srun --nodes=1 --ntasks=1 --cpus-per-task=${CPUS} --mem=${MEM} --time=${TIME_LIMIT} --pty bash -l"
