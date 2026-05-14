# CIVET Pipeline Reference

Step-by-step instructions for running CIVET 2.1.1 on BIDS/NIfTI or MINC data.

Official documentation: https://www.bic.mni.mcgill.ca/ServicesSoftware/CIVET-2-1-0-Table-of-Contents

## Step 0: Convert BIDS/NIfTI to MINC (skip if data is already MINC)

CIVET requires MINC format with strict naming: `<prefix>_<id>_t1.mnc`. Most modern datasets are NIfTI/BIDS and need conversion using `nii2mnc` (bundled inside the CIVET container).

```bash
bash <skill_path>/scripts/civet/convert_bids_to_minc.sh <config_file>
```

This finds all `sub-*/anat/*T1w.nii.gz` in the BIDS directory, converts each to MINC, renames to CIVET convention, and generates triplanar PNG previews with `mincpik` for visual QC before processing.

If optional T2/PD images exist, they are also converted as `<prefix>_<id>_t2.mnc` and `<prefix>_<id>_pd.mnc`.

**Pre-run checkpoint**:
```bash
bash <skill_path>/scripts/check_status.sh pre <bids_dir> "anat/*T1w.nii*"
```

## Step 1: Run CIVET on a single subject (testing)

Before batch processing, verify CIVET works on one subject:

```bash
bash <skill_path>/scripts/civet/run_civet.sh \
    <subject_id> <source_dir> <target_dir> <civet_img> \
    [prefix] [n3_distance] [extra_flags]
```

Expected runtime: **4-12 hours** depending on resolution and hardware.

**Recommended flags for 3T adult data** (set in config `CIVET_EXTRA_FLAGS`):
```
-lsq12 -resample-surfaces -thickness tlaplace:tfs:tlink 30:20 \
-VBM -combine-surfaces -correct-pve -mask-hippocampus -surface-atlas AAL \
-N3-distance 75
```

For high-quality scans, add `-interp sinc -template 0.50` for 0.5mm processing. For lower quality or older scans, use default `-interp linear -template 1.00` which hides some defects via light blurring.

## Step 2: Batch submit CIVET jobs via SLURM

```bash
bash <skill_path>/scripts/civet/submit_civet.sh <config_file> [start_index] [count]
```

Auto-skips subjects whose CIVET output already exists. Recommended batch size: ~100 subjects (smaller than fMRIPrep due to longer runtime).

**Post-run checkpoint**:
```bash
bash <skill_path>/scripts/check_status.sh post-log <log_dir>/civet "CIVET finished"
```

## Step 3: Quality control

CIVET produces verification images in `<target_dir>/<id>/verify/`. These PNG files must be visually reviewed:

| QC Image | What to check |
|---|---|
| `*_verify.png` | Linear registration quality (brain inside red model outline), tissue classification, surface overlays on classification |
| `*_clasp.png` | Surface extraction: masking errors, motion artifacts (jaggy white surface), gray surface under-expansion |
| `*_atlas.png` | Surface registration: central sulcus border between frontal/parietal lobes |
| `*_surfsurf.png` | Surface-surface intersections (pink spots): <500 is OK, >500 often indicates motion/masking defects |
| `*_laplace.png` | Gray surface convergence: green=good, red/white=over-expansion, blue/black=under-expansion |
| `*_angles.png` | Mesh distortion between white-to-gray expansion |
| `*_gradient.png` | T1w gradient at white surface position |
| `*_converg.png` | White/gray surface fitting convergence curves: look for flat lines (stagnation = incomplete convergence) |

Additionally, text-based QC files in `verify/`:
- `*_classify_qc.txt` — tissue classification percentages
- `*_surface_qc.txt` — surface extraction error metrics
- `*_civet_qc.txt` — processing variable values for QC table

Key QC metrics to flag (from `civet_qc.txt`):
- `MASK_ERROR` > 10%: brain mask problem
- `LEFT_INTER` or `RIGHT_INTER` > 100: self-intersections in resampled surface
- `LEFT_SURF_SURF` or `RIGHT_SURF_SURF` > 500: often motion artifacts or masking defects

Collect all QC images for batch review:
```bash
bash <skill_path>/scripts/civet/check_qc.sh <target_dir> <qc_output_dir>
```

## Step 4: Collect outputs for group analysis (optional)

```bash
bash <skill_path>/scripts/civet/collect_outputs.sh <target_dir> <subdirectory> <pattern> <output_dir>
```

## CIVET output directory structure

Each subject produces `<target_dir>/<id>/` containing:

| Folder | Contents |
|---|---|
| `native/` | Original images in native space (T1, T1 nuc-corrected) |
| `final/` | Images in stereotaxic space (T1 tal, T1 final nuc-corrected) |
| `transforms/linear/` | Linear transformations (native to stereotaxic) |
| `transforms/nonlinear/` | Non-linear transformation + deformation field |
| `transforms/surfreg/` | Surface registration maps (.sm files) |
| `mask/` | Brain masks (skull mask, brain-only mask) in stereotaxic space |
| `classify/` | Tissue classification (discrete + PVE), volume stats |
| `surfaces/` | White, gray, mid surfaces (.obj) original + resampled to MNI model; areas, volumes, gyrification, lobar stats |
| `thickness/` | Cortical thickness maps (native + resampled, per method per fwhm); cerebral volume stats; curvature if requested |
| `VBM/` | Voxel-based morphometry maps (if `-VBM` selected) |
| `segment/` | ANIMAL segmentation labels (if `-animal` selected) |
| `verify/` | QC images (.png) and QC text files |
| `logs/` | Stage logs, lock/running/failed/finished status files |

Key output files for downstream analysis:
- `thickness/*_native_rms_rsl_tlink_30mm_left.txt` — resampled cortical thickness, left hemisphere, 30mm smoothing
- `surfaces/*_white_surface_rsl_left_81920.obj` — resampled white surface mesh
- `surfaces/*_mid_surface_rsl_left_native_area_40mm.txt` — vertex-wise surface areas
- `classify/*_cls_volumes.dat` — tissue volumes in native space (CSF/GM/WM/subGM in mm3)
- `thickness/*_cerebral_volume.dat` — cortex volume in native space

## CIVET key options reference

| Option | Description | Recommended |
|---|---|---|
| `-N3-distance <val>` | Non-uniformity correction spline distance | 200 (1.5T), 75-125 (3T) |
| `-lsq12` | 12-parameter affine registration | Always use |
| `-resample-surfaces` | Resample surfaces for vertex-wise area/volume | Always use |
| `-thickness tlaplace:tfs:tlink <fwhm>` | Thickness methods and smoothing | `tlaplace:tfs:tlink 30:20` |
| `-VBM` | Voxel-based morphometry outputs | Recommended |
| `-combine-surfaces` | Combine left/right hemispheres | Recommended |
| `-correct-pve` | Iterative partial volume correction | Recommended |
| `-mask-hippocampus` | Mask hippocampus during extraction | Recommended |
| `-surface-atlas AAL` | Cortical parcellation atlas | AAL (default) |
| `-headheight <val>` | Neck-cropping height (mm) | 175 (adults), 170 (children) |
| `-template <val>` | Voxel size for stereotaxic space | 1.00 (standard), 0.50 (high-res) |
| `-interp sinc` | High-quality interpolation | Use with `-template 0.50` |
| `-multispectral` | Use T1+T2+PD for classification | If T2/PD available |
| `-mean-curvature` | Compute mean curvature maps | If needed |
| `-animal` | ANIMAL subcortical segmentation | If needed |
| `-reset-from <stage>` | Restart from a specific stage | For recovery |
| `-print-stages` | List pipeline stages without running | For debugging |

## Common failures and recovery

| Symptom | Likely cause | Fix |
|---|---|---|
| White surface extraction failure | Low quality, motion artifacts | Rerun with default `-interp linear -template 1.00` (drops sinc/0.50) |
| Gray surface under-expansion | Template mismatch, scan quality | Check `laplace.png` + `converg.png`, try different `-headheight` |
| Non-linear registration failure | Poor linear registration | Check input orientation, reconvert NIfTI with latest `nii2mnc` |
| Self-interpolation failure in white surface extraction (low-res/anisotropic scans) | Anisotropic voxels (e.g. 2mm slice thickness), marching-cubes produces >20 self-intersections that cannot be resolved during interpolation to 81920 mesh | No clean fix — rerun with a higher-quality T1. Try resampling to 1mm isotropic first, or pick a different session. Not recoverable via CIVET flags alone |
| Pipeline stalls at a stage | Disk space, memory, leftover lock files | Check `df -h`, check `.err` file, remove `.lock` files manually |
| Inversion error | Incorrect image orientation | Reconvert with `nii2mnc` (auto-detects orientation from NIfTI header) |
| Leftover `.running` files | Unexpected interruption | Remove `.running` files, rerun with `-reset-running` |

To identify failed stages:
```bash
# Check for .failed files
find <target_dir>/<id>/logs -name "*.failed"

# Check corresponding log
cat <target_dir>/<id>/logs/<id>.<failed_stage>.log

# Restart from the failed stage
# Add -reset-from <stage_name> to the CIVET command
```

To list all pipeline stages:
```bash
apptainer run <civet_img> CIVET_Processing_Pipeline \
    -sourcedir <source_dir> -targetdir <target_dir> -prefix <prefix> \
    -run -print-stages <id>
```

## Observed failure case: OAS30208 ses-M012 (2026-04-09)

First end-to-end test on Longleaf with OASIS3 subject OAS30208 (session M012).
Pipeline completed 13 stages successfully, then failed at `extract_white_surface_left`.

**Input characteristics:**
- T1w: `sub-OAS30208_ses-M012_T1w.nii.gz`
- Dimensions: 192 × 256 × 65 voxels
- Voxel size: 0.898 × 0.898 × 2.000 mm (anisotropic, 2mm slice thickness)
- Converted to MINC via `nii2mnc` inside the CIVET 2.1.1 container

**Environment:**
- Longleaf HPC, apptainer/1.4.1
- CIVET container: `docker://mcin/civet:2.1.1`
- Flags used: `-lsq12 -resample-surfaces -thickness tlaplace:tfs:tlink 30:20 -VBM -combine-surfaces -correct-pve -mask-hippocampus -surface-atlas AAL -N3-distance 75`

**What worked:**
Stages 1–13 all completed without errors: clean_native_scan, nuc_t1_native, stx_register, stx_tal_to_7/6, tal_t1, nuc_inorm_t1, mincbet_mask_stx, nlfit, mask_classify, cereb_vent_mask, pve, cortical_masking, surface_classify, create_wm_hemispheres. Right hemisphere white surface extraction (`extract_white_surface_right`) also completed successfully.

**What failed:**
Left hemisphere `extract_white_surface_left`. The marching-cubes step produced a 327680-triangle mesh, then during interpolation to the standard 81920-triangle mesh the algorithm encountered self-intersections. Over 56 repair iterations the self-intersection count oscillated between 9 and 35 without converging, and CIVET aborted with:

    Failed interpolation of marching-cubes surface with 33 self-intersections.

**Root cause (inferred):**
The 2mm anisotropic slice thickness produces poorly-defined white/gray boundaries in the through-slice direction. Marching cubes generates a jagged mesh whose high-frequency features cannot be cleanly resampled to the standard mesh topology. This is not a CIVET bug and not a pipeline configuration error — it is a known limitation of the surface extraction algorithm on low-resolution or anisotropic input.

**Lesson for the skill:**
`references/civet.md` should warn users that CIVET expects T1 input at ~1mm isotropic resolution. Datasets with slice thickness ≥ 2mm (common in older clinical scans, OASIS earlier releases, some legacy studies) may fail at `extract_white_surface_*` with no recoverable flag. Users should either (a) preprocess to resample to 1mm isotropic before handing to CIVET, or (b) select a different session/scan if the subject has multiple acquisitions.

**Elapsed time before failure:** ~2h 13min (pipeline started 2026-04-09 22:27, failed 2026-04-10 00:40).