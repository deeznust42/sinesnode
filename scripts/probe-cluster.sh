#!/usr/bin/env bash
# Run this ON THE CLUSTER MASTER NODE after your first SSH login.
# It gathers the facts we need to plan the LLM setup: OS, glibc, compilers,
# SLURM partitions, GPU presence, network egress, available modules.
#
# Usage (from the master node):
#   bash probe-cluster.sh > probe.txt 2>&1
# Then copy probe.txt back to your laptop:
#   scp sines:probe.txt ./probe-output/

set -u

section() { printf '\n========== %s ==========\n' "$1"; }

section "host"
hostname
uname -a
date

section "os"
cat /etc/os-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null || true

section "glibc"
ldd --version | head -1

section "cpu / memory"
lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Socket|MHz' || true
free -h

section "disk (home + scratch)"
df -h "$HOME" /scratch /tmp 2>/dev/null || df -h "$HOME" /tmp

section "compilers"
for c in gcc g++ cc cmake make python3 git; do
    if command -v "$c" >/dev/null 2>&1; then
        printf '%-8s %s\n' "$c" "$("$c" --version 2>&1 | head -1)"
    else
        printf '%-8s MISSING\n' "$c"
    fi
done

section "modules available"
if command -v module >/dev/null 2>&1; then
    module avail 2>&1 | head -100
else
    echo "Lmod/module not on PATH"
fi

section "slurm partitions"
sinfo 2>&1 || echo "sinfo unavailable"
echo
sinfo -N -l 2>&1 || true
echo
scontrol show partition 2>&1 || true

section "gpu check (master)"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
else
    echo "nvidia-smi not on master (expected — check via srun on a compute node next)"
fi

section "gpu check (compute via srun, 60s)"
timeout 90 srun --time=00:01:00 --ntasks=1 bash -c \
  'echo HOST=$(hostname); nvidia-smi 2>/dev/null || echo "no nvidia-smi on compute"; \
   echo; echo "/proc/cpuinfo cores:"; grep -c ^processor /proc/cpuinfo; \
   echo "MemTotal:"; awk "/MemTotal/{print \$2/1024/1024 \" GB\"}" /proc/meminfo' \
  2>&1 || echo "srun probe failed or queued — try later"

section "network egress test"
for url in https://huggingface.co https://github.com https://pypi.org; do
    if curl -sS -o /dev/null -w "%{http_code} %{url}\n" --max-time 8 "$url"; then :; fi
done

section "done"
echo "Probe finished at $(date)"
