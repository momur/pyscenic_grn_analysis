#!/bin/bash
# =============================================================================
# pyscenic_part3_aucell.sh
# -----------------------------------------------------------------------------
# pySCENIC step 3: AUCell — scores each cell for regulon activity using the
# regulons produced by part 1 & 2.
#
# Submit to SLURM:
#   sbatch pyscenic_part3_aucell.sh
#
# Output (per repeat):
#   <SUBSET>_AUCell_multimotif_<N>.loom   cell × regulon AUC matrix
# =============================================================================

#SBATCH --job-name="pyscenic_aucell"
#SBATCH --account=st-wasser-1
#SBATCH -t 72:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --mem=256G
#SBATCH --output=logs/pyscenic_aucell_%j.out
#SBATCH --error=logs/pyscenic_aucell_%j.err

set -euo pipefail

# ── Environment ───────────────────────────────────────────────────────────────
cd "$SLURM_SUBMIT_DIR"
source ~/.bashrc
conda activate pyscenic_test

# ── Uncomment if you hit TMPDIR / Dask / Numba cache errors ──────────────────
# export TMPDIR="./pyscenic_tmp_${SLURM_JOB_ID}"
# mkdir -p "$TMPDIR"
# export DASK_TEMPORARY_DIRECTORY="$TMPDIR/dask"
# export DASK_WORKER_DIR="$TMPDIR/dask"
# export NUMBA_CACHE_DIR="$TMPDIR/numba"
# mkdir -p "$DASK_TEMPORARY_DIRECTORY" "$NUMBA_CACHE_DIR"

# ── Input / output paths ──────────────────────────────────────────────────────
SUBSET="hi_low_beta_labelled_pyscenic_input"   # base name of your .loom file
REGULONS="regulons.csv"                         # regulons CSV from part 2
N_REPEATS=1                                     # number of AUCell repeats to run
NUM_WORKERS=4                                   # parallel workers

# ── Sanity checks ─────────────────────────────────────────────────────────────
mkdir -p logs

for f in "${SUBSET}.loom" "$REGULONS"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: required file not found: $f" >&2
        exit 1
    fi
done

# ── Run AUCell ────────────────────────────────────────────────────────────────
echo "Starting pySCENIC part 3 (AUCell) — ${N_REPEATS} repeat(s), ${NUM_WORKERS} workers"
echo "Input loom : ${SUBSET}.loom"
echo "Regulons   : $REGULONS"

for repeat in $(seq 1 "$N_REPEATS"); do
    echo "━━━ Repeat ${repeat} / ${N_REPEATS} ━━━"

    AUCELL_OUT="${SUBSET}_AUCell_multimotif_${repeat}.loom"

    echo "[$(date '+%H:%M:%S')] Part 3 — AUCell"
    pyscenic aucell \
        "${SUBSET}.loom" \
        "$REGULONS" \
        --output "$AUCELL_OUT" \
        --num_workers "$NUM_WORKERS"

    echo "[$(date '+%H:%M:%S')] Done → $AUCELL_OUT"
done

echo "All AUCell repeats complete."
conda deactivate
