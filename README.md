# CIVET Pipeline

This repository provides helper scripts and wrappers to run the CIVET cortical surface extraction and morphometry pipeline on SLURM HPC systems using Apptainer/Spack-style containers.

**Contents**
- `scripts/` — wrapper scripts to convert inputs, submit jobs, run CIVET, collect outputs and check QC.
- `scripts/civet/` — CIVET-specific helpers: `convert_bids_to_minc.sh`, `run_civet.sh`, `submit_civet.sh`, `collect_outputs.sh`, `check_qc.sh`.
- `pipeline.env.template` — example environment configuration template.

Overview

CIVET produces cortical thickness, surface area, curvature, and parcellation outputs from T1-weighted MRI (optionally T2/PD). These scripts help prepare inputs (BIDS → MINC), submit CIVET jobs to SLURM, and collect & QC outputs.

Quickstart

1. Copy the environment template and fill the variables:

```bash
cp pipeline.env.template .env
# Edit .env to set paths, container image, SLURM params
```

2. Convert BIDS data to MINC (if starting from BIDS):

```bash
scripts/civet/convert_bids_to_minc.sh --bids /path/to/BIDS --out /path/to/minc --subject <SUBJ>
```

3. Submit CIVET processing:

```bash
scripts/civet/submit_civet.sh --subject <SUBJ> --minc-dir /path/to/minc
```

4. After jobs complete, collect outputs and run QC:

```bash
scripts/civet/collect_outputs.sh --subject <SUBJ> --out /path/to/results
scripts/civet/check_qc.sh --results /path/to/results
```

Key files

- `pipeline.env.template` — environment variables for container, CIVET version, resource defaults.
- `scripts/civet/submit_civet.sh` — SLURM submission wrapper; customize for your cluster.
- `scripts/civet/run_civet.sh` — entrypoint to call CIVET inside the container.
- `scripts/civet/collect_outputs.sh` — gathers MINC outputs, surfaces, and summary CSVs.

Inputs & Outputs

- Inputs: MINC-formatted anatomical images (T1, optionally T2/PD), and a subject ID. If starting from BIDS, use the converter script.
- Outputs: cortical thickness maps, surface meshes, parcellations, QC logs, and summary CSVs suitable for downstream analysis.

Customization

- Edit `.env` (from `pipeline.env.template`) to set container image, civet version, and SLURM options (time, mem, cpus).
- Modify `submit_civet.sh` for site-specific account/partition settings.

Troubleshooting

- Check SLURM job logs for errors (stdout/stderr) in the SLURM work directory.
- Ensure the container image includes CIVET and MINC toolchain or point to an image that does.
- If conversions fail, verify BIDS path and permissions.

Contributing

Contributions are welcome. Create issues or PRs describing the change. Keep edits targeted to scripts or templates and include example commands or tests where possible.

License

License is not specified in this repository. Add a `LICENSE` file if you intend to share under a specific license.

Contact

For questions about these scripts, open an issue in this repository with details and relevant logs.
