#!/bin/bash
# =============================================================================
# pyscenic_part1_2_grn_ctx.sh
# -----------------------------------------------------------------------------
# pySCENIC steps 1 & 2: GRN inference (GRNBoost2) + cis-regulatory analysis
# (RcisTarget). Runs N independent repeats with different random seeds to
# assess reproducibility of the gene regulatory network.
#
# Submit to SLURM:
#   sbatch pyscenic_part1_2_grn_ctx.sh
#
# Output (per repeat):
#   <SUBSET>_adjacencies_<N>.csv   co-expression modules from GRNBoost2
#   <SUBSET>_regulons_<N>.csv      regulons from RcisTarget
# =============================================================================

#SBATCH --job-name="pyscenic_grn_ctx"
#SBATCH --account=st-w
#SBATCH -t 72:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --mem=256G
#SBATCH --output=logs/pyscenic_grn_ctx_%j.out
#SBATCH --error=logs/pyscenic_grn_ctx_%j.err

set -euo pipefail   # exit on error, undefined variable, or pipe failure

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
# Edit these variables to match your project layout.

SUBSET="hi_low_beta_labelled_pyscenic_input"   # base name of your .loom file
SHARED_DIR="../pyscenic_allcelltypes"           # directory with shared reference files
N_REPEATS=5                                     # number of independent GRN repeats
NUM_WORKERS=4                                   # parallel workers per pySCENIC step

# Reference files (download from https://resources.aertslab.org/cistarget/)
LIST_TFS="${SHARED_DIR}/hs_hgnc_tfs.txt"
RANKING_DB="${SHARED_DIR}/hg38_10kbp_up_10kbp_down_full_tx_v10_clust.genes_vs_motifs.rankings.feather"
MOTIF_ANN="${SHARED_DIR}/motifs-v10nr_clust-nr.hgnc-m0.001-o0.0.tbl"

# ── Sanity checks ─────────────────────────────────────────────────────────────
mkdir -p logs

for f in "${SUBSET}.loom" "$LIST_TFS" "$RANKING_DB" "$MOTIF_ANN"; do
    if [[ ! -f "$f" ]]; then
        echo "ERROR: required file not found: $f" >&2
        exit 1
    fi
done

# ── Run N repeats ─────────────────────────────────────────────────────────────
echo "Starting pySCENIC parts 1 & 2 — ${N_REPEATS} repeat(s), ${NUM_WORKERS} workers"
echo "Input loom : ${SUBSET}.loom"
echo "TF list    : $LIST_TFS"
echo "Ranking DB : $RANKING_DB"
echo "Motif ann  : $MOTIF_ANN"

for repeat in $(seq 1 "$N_REPEATS"); do
    echo "━━━ Repeat ${repeat} / ${N_REPEATS} ━━━"

    ADJ_OUT="${SUBSET}_adjacencies_${repeat}.csv"
    REG_OUT="${SUBSET}_regulons_${repeat}.csv"

    # Part 1: GRN inference with GRNBoost2
    echo "[$(date '+%H:%M:%S')] Part 1 — GRN inference (seed=${repeat})"
    pyscenic grn \
        "${SUBSET}.loom" \
        "$LIST_TFS" \
        -o "$ADJ_OUT" \
        --num_workers "$NUM_WORKERS" \
        --seed "$repeat"

    # Part 2: cis-regulatory motif analysis with RcisTarget
    echo "[$(date '+%H:%M:%S')] Part 2 — RcisTarget"
    pyscenic ctx \
        "$ADJ_OUT" \
        "$RANKING_DB" \
        --annotations_fname "$MOTIF_ANN" \
        --expression_mtx_fname "${SUBSET}.loom" \
        --output "$REG_OUT" \
        --num_workers "$NUM_WORKERS"

    echo "[$(date '+%H:%M:%S')] Repeat ${repeat} done → $REG_OUT"
done

echo "All repeats complete."
conda deactivate
