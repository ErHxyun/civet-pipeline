#!/bin/bash
set -euo pipefail
# =============================================================================
# Convert BIDS/NIfTI T1w images to MINC format for CIVET
# =============================================================================
# Usage: convert_bids_to_minc.sh <config_file>
#
# Converts all sub-*/anat/*T1w.nii.gz files to <prefix>_<id>_t1.mnc
# Also converts T2w and PD if present.
# Uses nii2mnc from inside the CIVET container.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:?Usage: convert_bids_to_minc.sh <config_file>}"

source "$CONFIG"

for var in BIDS_DIR SOURCE_DIR CIVET_IMG CIVET_PREFIX; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $var not set in config file"
        exit 1
    fi
done

PREFIX="${CIVET_PREFIX}"

mkdir -p "${SOURCE_DIR}"

# Pre-run checkpoint
echo "=== Pre-run checkpoint: checking BIDS T1w inputs ==="
bash "${SCRIPT_DIR}/../check_status.sh" pre "${BIDS_DIR}" "anat/*T1w.nii*"
echo ""

converted=0
skipped=0
failed=0

for subj_dir in "${BIDS_DIR}"/sub-*/; do
    [[ -d "$subj_dir" ]] || continue
    subject=$(basename "$subj_dir" | sed 's/^sub-//')

    # Find T1w (prefer non-session, fall back to first session)
    t1w=""
    for candidate in \
        "${subj_dir}/anat/sub-${subject}_T1w.nii.gz" \
        "${subj_dir}/anat/sub-${subject}_T1w.nii" \
        "${subj_dir}"/ses-*/anat/sub-${subject}_ses-*_T1w.nii.gz \
        "${subj_dir}"/ses-*/anat/sub-${subject}_ses-*_T1w.nii; do
        if [[ -f "$candidate" ]]; then
            t1w="$candidate"
            break
        fi
    done

    if [[ -z "$t1w" ]]; then
        echo "WARNING: No T1w found for sub-${subject}, skipping"
        continue
    fi

    outfile="${SOURCE_DIR}/${PREFIX}_${subject}_t1.mnc"
    if [[ -f "$outfile" ]]; then
        skipped=$((skipped + 1))
        continue
    fi

    echo "Converting: sub-${subject} → ${PREFIX}_${subject}_t1.mnc"

    if apptainer exec "${CIVET_IMG}" nii2mnc "$t1w" "$outfile" 2>/dev/null; then
        # Generate triplanar preview for visual QC
        apptainer exec "${CIVET_IMG}" mincpik -triplanar "$outfile" \
            "${SOURCE_DIR}/${PREFIX}_${subject}_t1.png" 2>/dev/null || true
        converted=$((converted + 1))
    else
        echo "ERROR: Conversion failed for sub-${subject}"
        failed=$((failed + 1))
    fi

    # Also convert T2 if present
    for t2w in "${subj_dir}/anat/sub-${subject}_T2w.nii.gz" \
               "${subj_dir}"/ses-*/anat/sub-${subject}_ses-*_T2w.nii.gz; do
        if [[ -f "$t2w" ]]; then
            t2out="${SOURCE_DIR}/${PREFIX}_${subject}_t2.mnc"
            if [[ ! -f "$t2out" ]]; then
                apptainer exec "${CIVET_IMG}" nii2mnc "$t2w" "$t2out" 2>/dev/null || true
            fi
            break
        fi
    done
done

echo ""
echo "=== Conversion summary ==="
echo "Converted: $converted | Skipped (already done): $skipped | Failed: $failed"
echo "MINC files in ${SOURCE_DIR}:"
ls "${SOURCE_DIR}"/*_t1.mnc 2>/dev/null | wc -l | xargs -I{} echo "  T1: {} files"
ls "${SOURCE_DIR}"/*_t2.mnc 2>/dev/null | wc -l | xargs -I{} echo "  T2: {} files"
