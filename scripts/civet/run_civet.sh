#!/bin/bash
set -euo pipefail
# =============================================================================
# Run CIVET on a single subject
# =============================================================================
# Usage: run_civet.sh <subject_id> <source_dir> <target_dir> <civet_img> \
#                     [prefix] [n3_distance] [extra_flags...]
#
# Example:
#   run_civet.sh OAS30208 /data/minc /data/civet_out /images/civet.sif \
#                study 75 -interp sinc -template 0.50
# =============================================================================

subject="$1"
source_dir="$2"
target_dir="$3"
civet_img="$4"
prefix="${5:-study}"
n3_distance="${6:-200}"
shift 6 2>/dev/null || true
extra_flags=("$@")

echo "[INFO] Running CIVET for ${prefix}_${subject}"
echo "[INFO] Source: ${source_dir}"
echo "[INFO] Target: ${target_dir}"
echo "[INFO] N3 distance: ${n3_distance}"

# Pre-run: verify input exists
input_t1="${source_dir}/${prefix}_${subject}_t1.mnc"
if [[ ! -f "${input_t1}" ]]; then
    echo "ERROR: Input not found: ${input_t1}"
    exit 1
fi

mkdir -p "${target_dir}"

apptainer run --cleanenv \
    "${civet_img}" \
    CIVET_Processing_Pipeline \
    -sourcedir "${source_dir}" \
    -targetdir "${target_dir}" \
    -prefix "${prefix}" \
    -N3-distance "${n3_distance}" \
    "${extra_flags[@]}" \
    -spawn \
    -run \
    "${subject}"

echo "[INFO] CIVET finished for ${prefix}_${subject}"
