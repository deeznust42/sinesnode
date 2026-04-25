#!/usr/bin/env bash
# Copy this repo (minus models/git/etc.) up to the cluster home directory.
# Run from the repo root on your LAPTOP.
set -euo pipefail

REMOTE="${REMOTE:-sines}"      # ssh host alias from ssh/config-snippet
DEST="${DEST:-~/sinesnode}"    # destination on master

cd "$(dirname "$0")/.."

rsync -avz --delete \
    --exclude '.git' \
    --exclude 'models' \
    --exclude 'local' \
    --exclude 'probe-output' \
    --exclude '.DS_Store' \
    ./ "${REMOTE}:${DEST}/"

echo
echo "Synced to ${REMOTE}:${DEST}"
echo "Next: ssh ${REMOTE}  →  cd ${DEST}  →  bash scripts/probe-cluster.sh"
