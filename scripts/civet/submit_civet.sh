#!/bin/bash
set -euo pipefail
# =============================================================================
# Batch submit CIVET jobs via SLURM
# =============================================================================
# Usage: submit_civet.sh <config_file> [start_index] [count]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:?Usage: submit_civet.sh <config_file> [start_index] [count]}"
START_IDX="${2:-0}"
COUNT="${3:-0}"  # 0 = all remaining

source "$CONFIG"

for var in SOURCE_DIR TARGET_DIR LOG_DIR CIVET_IMG CIVET_PREFIX; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $var not set in config file"
        exit 1
    fi
done

PREFIX="${CIVET_PREFIX}"
N3="${CIVET_N3_DISTANCE:-200}"
EXTRA="${CIVET_EXTRA_FLAGS:-"-lsq12 -resample-surfaces -thickness tlaplace:tfs:tlink 30:20 -VBM -combine-surfaces"}"

mkdir -p "${LOG_DIR}/civet"

# Pre-run checkpoint
echo "=== Pre-run checkpoint: checking MINC inputs ==="
t1_count=$(ls "${SOURCE_DIR}"/${PREFIX}_*_t1.mnc 2>/dev/null | wc -l)
echo "Found ${t1_count} T1 MINC files in ${SOURCE_DIR}"
if [[ ${t1_count} -eq 0 ]]; then
    echo "ERROR: No MINC files found matching ${PREFIX}_*_t1.mnc in ${SOURCE_DIR}"
    echo "Run convert_bids_to_minc.sh first if your data is in NIfTI/BIDS format."
    exit 1
fi
echo ""

# Collect subject IDs from MINC filenames
subjects=()
for f in "${SOURCE_DIR}"/${PREFIX}_*_t1.mnc; do
    [[ -f "$f" ]] || continue
    # Extract ID: <prefix>_<id>_t1.mnc → <id>
    fname=$(basename "$f")
    id="${fname#${PREFIX}_}"
    id="${id%_t1.mnc}"
    subjects+=("$id")
done

# Apply start/count
if [[ $COUNT -gt 0 ]]; then
    subjects=("${subjects[@]:$START_IDX:$COUNT}")
else
    subjects=("${subjects[@]:$START_IDX}")
fi

echo "Submitting ${#subjects[@]} CIVET jobs..."

submitted=0
skipped=0
for subject in "${subjects[@]}"; do
    outfile="${LOG_DIR}/civet/${subject}.out"

    # Skip if already completed
    if [[ -f "$outfile" ]] && tail -n 30 "$outfile" 2>/dev/null | grep -q "Pipeline finished\|CIVET finished"; then
        skipped=$((skipped + 1))
        continue
    fi

    # Skip if CIVET output directory already has key outputs
    if [[ -d "${TARGET_DIR}/${subject}/thickness" ]] && \
       ls "${TARGET_DIR}/${subject}/thickness/"*_tlink_*.txt &>/dev/null; then
        skipped=$((skipped + 1))
        continue
    fi

    sbatch -n 1 --cpus-per-task "${SLURM_CPUS:-4}" \
        -t "${SLURM_TIME:-0-14:00:00}" \
        --mem="${SLURM_MEM:-16g}" \
        --export=ALL \
        -o "${LOG_DIR}/civet/${subject}.out" \
        -e "${LOG_DIR}/civet/${subject}.err" \
        --wrap="bash ${SCRIPT_DIR}/run_civet.sh ${subject} ${SOURCE_DIR} ${TARGET_DIR} ${CIVET_IMG} ${PREFIX} ${N3} ${EXTRA}"

    submitted=$((submitted + 1))
done

echo "Submitted: $submitted | Skipped (already done): $skipped"
echo ""
echo "=== Monitor with: ==="
echo "  squeue -u \$USER"
echo ""
echo "=== Post-run checkpoint (after jobs finish): ==="
echo "  bash ${SCRIPT_DIR}/../check_status.sh post-log ${LOG_DIR}/civet 'Pipeline finished'"
