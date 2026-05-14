---
name: civet-pipeline
description: "CIVET cortical surface extraction and morphometry pipeline for SLURM HPC clusters. Runs CIVET_Processing_Pipeline via Apptainer/Docker to produce cortical thickness, surface area, curvature, and parcellation data from T1-weighted (and optionally T2/PD) MRI images. Use this skill when the user wants to run CIVET, extract cortical thickness, generate cortical surfaces, process structural MRI data with CIVET, convert NIfTI/BIDS data to MINC for CIVET input, or perform cortical morphometry. Trigger for any mention of CIVET, CIVET_Processing_Pipeline, cortical thickness with CIVET, MINC conversion, or MNI surface extraction."
---

# CIVET Cortical Surface Extraction Pipeline

Runs **CIVET 2.1.1** on any SLURM HPC cluster with Apptainer to produce cortical thickness maps, surface meshes, parcellations, and volumetric brain morphometry from T1-weighted MRI images.

All pipeline scripts are bundled under `scripts/civet/`. Each script takes all paths as arguments — no manual path editing needed. Cluster-specific settings are centralized in a single config file.

## Pipeline overview

CIVET takes T1-weighted images (optionally T2 and PD) and produces:

| Output | Description |
|---|---|
| Cortical surfaces | White/gray and gray/CSF boundary meshes (~80k vertices) |
| Cortical thickness | Vertex-wise thickness maps (native + MNI space) |
| Surface area & volume | Vertex-wise and lobar measurements |
| Curvature | Mean curvature maps |
| Tissue classification | WM/GM/CSF segmentation |
| Parcellation | AAL or other atlas-based cortical parcellation |
| QC images | Triplanar PNG views for visual quality control |

For detailed step-by-step instructions, read: `references/civet.md`

## Input requirements

CIVET requires images in **MINC format** with a specific naming convention:

```
<sourcedir>/<prefix>_<id>_t1.mnc        # T1-weighted (required)
<sourcedir>/<prefix>_<id>_t2.mnc        # T2-weighted (optional)
<sourcedir>/<prefix>_<id>_pd.mnc        # Proton density (optional)
<sourcedir>/<prefix>_<id>_mask.mnc      # Brain mask (optional)
```

If the user has **BIDS/NIfTI data**, run the conversion step first (see `references/civet.md` Step 0).

## Required user inputs

Before running, collect from the user:

1. **`BIDS_DIR`** or **`SOURCE_DIR`** — Path to input data (NIfTI/BIDS or already-converted MINC)
2. **`TARGET_DIR`** — Where CIVET outputs go (one subdirectory per subject)
3. **`WORK_DIR`** — Temporary processing directory
4. **`LOG_DIR`** — Where SLURM `.out`/`.err` files go
5. **`CONFIG_FILE`** — Path to the user's `pipeline.env` (created from template)

## Setup: create config file

Before first use, create a config file from the template at `scripts/pipeline.env.template`:

```bash
cp <skill_path>/scripts/pipeline.env.template ~/civet_pipeline.env
# Edit ~/civet_pipeline.env to set all paths for your cluster
```

The config file declares:

- **`APPTAINER_BIND`** — Filesystem paths the container needs (cluster-specific)
- **`CIVET_IMG`** — Path to CIVET Apptainer/Docker image
- **`CIVET_PREFIX`** — Study prefix for CIVET naming convention
- **`CIVET_N3_DISTANCE`** — N3 correction distance (200 for 1.5T, 50-125 for 3T)
- **`SLURM_CPUS`**, **`SLURM_MEM`**, **`SLURM_TIME`** — Resource defaults

The CIVET container image is **not** bundled with the skill. Obtain it from:
- Docker Hub: `docker pull mcin/civet:2.1.1`
- Or build from source: https://github.com/aces/CIVET_Full_Project

## Checkpoints

Every step has built-in checkpoints via `scripts/check_status.sh`:

```bash
# Check BIDS inputs exist before conversion
bash <skill_path>/scripts/check_status.sh pre <bids_dir> "anat/*T1w.nii*"

# Check MINC conversion completed
bash <skill_path>/scripts/check_status.sh pre <source_dir> "*_t1.mnc"

# Check CIVET outputs after processing
bash <skill_path>/scripts/check_status.sh post-log <log_dir>/civet "Pipeline finished"
```

## HPC environment

```bash
# Use interactive node for testing
srun -t 12:00:00 -p interact -N 1 --pty /bin/bash

# Job management
squeue -u $USER       # check job status
scancel -u $USER      # cancel all jobs
```

## Processing strategy for large datasets

- CIVET runtime is 4-12 hours per subject — plan batch sizes accordingly
- Process in batches of ~100 subjects (smaller than fMRIPrep due to longer runtime)
- Use `submit_civet.sh` which auto-skips already-completed subjects
- Run `cleanup_work.sh` concurrently if work directory space is limited
- Check completion after each batch with `check_status.sh post-log`