# sinesnode

Local tooling for using the **NUST SINES SCREC** OpenHPC cluster (master `10.19.10.160`)
to run a local LLM via SLURM and access it from your laptop.

## The shape of the workflow

The cluster is shared and SLURM-scheduled. There is no node where a persistent service
is allowed to live. Instead, every session looks like this:

```
laptop ──ssh──▶ master ──sbatch──▶ compute node (runs llama-server for N hours)
   │                                        ▲
   └────── ssh -L tunnel through master ────┘
```

You submit a SLURM job that launches `llama-server` on a compute node, then your laptop
opens a port-forward through master so you can hit `http://localhost:8080` locally.
When the job's wall-clock time runs out, the server dies and you re-submit.

## Layout

| Path | What it does | Where it runs |
|---|---|---|
| `ssh/config-snippet` | Append to `~/.ssh/config` to enable `ssh sines` | laptop, once |
| `scripts/sync-to-cluster.sh` | Push this repo to `~/sinesnode` on master | laptop |
| `scripts/probe-cluster.sh` | Gather OS, GPU, SLURM, network facts | master, once |
| `scripts/bootstrap-llama.sh` | Build llama.cpp + download a model (via `srun`) | master, once |
| `slurm/llama-server.sbatch` | SLURM job that runs `llama-server` | submitted on master |
| `scripts/connect-llm.sh` | Tunnel `localhost:8080` to the running job | laptop, every session |
| `scripts/interactive.sh` | Drop into an interactive shell on a compute node | laptop |

Reference docs from SINES are kept at the repo root:
- `HPC-Cluster-Access-and-Usage-Manual.pdf`
- `List-of-Software-Installed-on-Supercomputer.pdf`

## First-time setup

You must be on the NUST campus network (or NUST VPN) for any of this to reach the cluster.

1. **Add the SSH alias** (one-time, on your laptop):
   ```
   cat ssh/config-snippet >> ~/.ssh/config
   ```
   Verify: `ssh sines` should prompt for your password and log you in.

2. **Change your default password** on first login (the email gave you `sines@123`):
   ```
   ssh sines
   passwd
   ```

3. **Push this repo to the cluster:**
   ```
   bash scripts/sync-to-cluster.sh
   ```

4. **Probe the cluster** so we know what we're working with:
   ```
   ssh sines 'cd ~/sinesnode && bash scripts/probe-cluster.sh' > probe-output/probe.txt
   ```
   Read `probe.txt`. The things that matter most: OS + glibc version, presence of
   `gcc`/`cmake`, SLURM partition names + time limits, whether `nvidia-smi` works on
   any compute node, whether outbound HTTPS to huggingface.co works.

5. **Bootstrap llama.cpp + the default model** (one-time, ~30–45 min):
   ```
   ssh sines 'cd ~/sinesnode && bash scripts/bootstrap-llama.sh'
   ```
   The default is Qwen2.5-7B-Instruct Q4_K_M (~4.7 GB). Override with `MODEL_URL=…`.

## Running the LLM

Every session:

1. **On the cluster — submit the server job:**
   ```
   ssh sines 'cd ~/sinesnode && sbatch slurm/llama-server.sbatch'
   ```
   Watch it start: `ssh sines squeue --me`. Once `ST=R` (running), it has launched.

2. **On your laptop — open the tunnel:**
   ```
   bash scripts/connect-llm.sh
   ```
   Leave it running. Visit `http://localhost:8080` in a browser, or point any
   OpenAI-compatible client at `http://localhost:8080/v1`.

3. **End the session** (or just let the wall-clock time out):
   ```
   ssh sines scancel -u zain.ikhlaq
   ```

## Quick interactive use (no server, just chat in a terminal)

```
bash scripts/interactive.sh
# you're now on a compute node:
~/llama.cpp/build/bin/llama-cli -m ~/models/qwen2.5-7b-instruct-q4_k_m.gguf -cnv
```

## Performance expectations

CPU-only inference (which this cluster almost certainly is — to be confirmed by probe):

| Model | Quant | Approx. speed | RAM |
|---|---|---|---|
| 7B   | Q4_K_M | 3–8 tok/s   | ~6 GB |
| 13B  | Q4_K_M | 1–3 tok/s   | ~10 GB |
| 30B+ | —      | impractical | — |

Anything beyond a 13B class model on CPU will be too slow for interactive use.
If the probe surprises us with usable GPUs, we revisit.

## Troubleshooting

- **`ssh sines` times out:** you're not on NUST network or VPN. Nothing else works
  until the cluster is reachable.
- **`sbatch` rejects the time/mem request:** the partition has a lower limit than
  the script asks for. Read `scontrol show partition` (in `probe.txt`) and lower the
  `#SBATCH --time` / `--mem` directives.
- **`connect-llm.sh` says "no info file":** the job hasn't started yet, or it crashed.
  `ssh sines 'tail llama-server-*.log'` to see why.
- **Long compile / download fails mid-way:** re-run `bootstrap-llama.sh`; both
  steps are idempotent.
