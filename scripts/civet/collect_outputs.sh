#!/bin/bash
set -euo pipefail
# =============================================================================
# Collect specific CIVET outputs across subjects for group analysis
# =============================================================================
# Usage: collect_outputs.sh <target_dir> <subdirectory> <pattern> <output_dir>
#
# Examples:
#   # Collect all 30mm tlink thickness files
#   collect_outputs.sh /data/civet_out thickness "*_native_rms_rsl_tlink_30mm_*.txt" /data/group/thickness
#
#   # Collect all resampled white surfaces
#   collect_outputs.sh /data/civet_out surfaces "*_white_surface_rsl_*_81920.obj" /data/group/surfaces
#
#   # Collect tissue classification volumes
#   collect_outputs.sh /data/civet_out classify "*_cls_volumes.dat" /data/group/volumes
# =============================================================================

TARGET_DIR="${1:?Usage: collect_outputs.sh <target_dir> <subdirectory> <pattern> <output_dir>}"
SUBDIR="${2:?Missing subdirectory (e.g., thickness, surfaces, classify)}"
PATTERN="${3:?Missing file pattern}"
OUTPUT_DIR="${4:?Missing output_dir}"

mkdir -p "${OUTPUT_DIR}"

collected=0
missing=0

for subj_dir in "${TARGET_DIR}"/*/; do
    [[ -d "$subj_dir" ]] || continue
    subject=$(basename "$subj_dir")
    search_dir="${subj_dir}/${SUBDIR}"

    if [[ ! -d "$search_dir" ]]; then
        missing=$((missing + 1))
        continue
    fi

    found=false
    for f in $(find "$search_dir" -name "$PATTERN" 2>/dev/null); do
        cp "$f" "${OUTPUT_DIR}/"
        found=true
        collected=$((collected + 1))
    done

    if ! $found; then
        missing=$((missing + 1))
    fi
done

echo "=== Collection summary ==="
echo "Pattern: ${SUBDIR}/${PATTERN}"
echo "Files collected: $collected"
echo "Subjects missing: $missing"
echo "Output: ${OUTPUT_DIR}/"
