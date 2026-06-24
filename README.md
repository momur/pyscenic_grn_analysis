# pySCENIC Gene Regulatory Network Pipeline

SLURM-ready pipeline for running [pySCENIC](https://pyscenic.readthedocs.io/) on an HPC cluster. Identifies gene regulatory networks (GRNs) and scores regulon activity in single-cell RNA-seq data.

## Workflow

```
Input: <subset>.loom  +  reference files (TF list, ranking DB, motif annotations)
         │
         ▼
  Part 1: GRNBoost2 — co-expression modules  →  <subset>_adjacencies_<N>.csv
         │
         ▼
  Part 2: RcisTarget — cis-regulatory motifs  →  <subset>_regulons_<N>.csv
         │
         ▼
  Part 3: AUCell — regulon activity scores  →  <subset>_AUCell_multimotif_<N>.loom
```

Parts 1 & 2 are run as a single job (`pyscenic_part1_2_grn_ctx.sh`) with N independent
repeats (different random seeds) to assess GRN reproducibility. Part 3
(`pyscenic_part3_aucell.sh`) takes the merged regulons and scores cells.

## Setup

### 1. Create the conda environment

```bash
conda env create -f pyscenic_conda_env.yml
conda activate pyscenic_test
```

### 2. Download reference files

From the [Aerts lab resources](https://resources.aertslab.org/cistarget/):

| File | Description |
|---|---|
| `hs_hgnc_tfs.txt` | Human TF list (HGNC symbols) |
| `hg38_10kbp_up_10kbp_down_full_tx_v10_clust.genes_vs_motifs.rankings.feather` | hg38 cisTarget ranking database |
| `motifs-v10nr_clust-nr.hgnc-m0.001-o0.0.tbl` | Motif annotation table |

### 3. Prepare your input

Your input `.loom` file should be a single-cell expression matrix. Export it
from Seurat or AnnData using `loompy` or `SCopeLoomR`.

## Usage

Edit the variables at the top of each script to set your paths, then submit:

```bash
# Parts 1 & 2 — GRN inference + motif analysis (runs N_REPEATS times)
sbatch pyscenic_part1_2_grn_ctx.sh

# Part 3 — AUCell scoring (run after part 2 is complete)
sbatch pyscenic_part3_aucell.sh
```

Key variables to set in each script:

| Variable | Description |
|---|---|
| `SUBSET` | Base name of your `.loom` file (without extension) |
| `SHARED_DIR` | Directory containing the reference files |
| `N_REPEATS` | Number of independent GRN repeats (default: 5) |
| `NUM_WORKERS` | Parallel workers per pySCENIC step (default: 4) |

## Output files

| File | Description |
|---|---|
| `<SUBSET>_adjacencies_<N>.csv` | Co-expression modules (GRNBoost2) |
| `<SUBSET>_regulons_<N>.csv` | Regulons with motif support (RcisTarget) |
| `<SUBSET>_AUCell_multimotif_<N>.loom` | Cell × regulon AUC scores |
| `logs/pyscenic_*.out` / `.err` | SLURM job logs |

## Notes

- Parts 1 & 2 are stochastic — running 5 repeats and taking the consensus
  improves reliability. See the [pySCENIC best practices](https://pyscenic.readthedocs.io/en/latest/tutorial.html).
- If you hit TMPDIR/Dask/Numba errors, uncomment the `TMPDIR` block near the
  top of each script.
- Python 3.7 is required for pySCENIC 0.12.x. Do not upgrade to Python 3.8+
  without also upgrading pySCENIC.

## Citation

> Van de Sande et al. (2020). A scalable SCENIC workflow for single-cell gene
> regulatory network analysis. *Nature Protocols*.
