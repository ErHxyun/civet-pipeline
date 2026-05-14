#!/bin/bash
set -euo pipefail
# =============================================================================
# Collect CIVET QC images and metrics for batch review
# =============================================================================
# Usage: check_qc.sh <target_dir> <qc_output_dir>
#
# Copies all verify/*.png and verify/*_qc.txt into a flat directory
# and produces a summary CSV of key QC metrics.
# =============================================================================

TARGET_DIR="${1:?Usage: check_qc.sh <target_dir> <qc_output_dir>}"
QC_DIR="${2:?Missing qc_output_dir}"

mkdir -p "${QC_DIR}/images" "${QC_DIR}/metrics"

# Header for summary CSV
echo "subject,mask_error,wm_pct,gm_pct,csf_pct,left_inter,right_inter,left_surfsurf,right_surfsurf" \
    > "${QC_DIR}/qc_summary.csv"

total=0
collected=0

for subj_dir in "${TARGET_DIR}"/*/; do
    [[ -d "${subj_dir}/verify" ]] || continue
    subject=$(basename "$subj_dir")
    total=$((total + 1))

    # Copy QC images
    for png in "${subj_dir}/verify/"*.png; do
        [[ -f "$png" ]] || continue
        cp "$png" "${QC_DIR}/images/"
    done

    # Copy QC text files
    for txt in "${subj_dir}/verify/"*_qc.txt; do
        [[ -f "$txt" ]] || continue
        cp "$txt" "${QC_DIR}/metrics/"
    done

    # Extract key metrics from civet_qc.txt if present
    qc_file="${subj_dir}/verify/"*_civet_qc.txt
    qc_file=$(ls ${subj_dir}/verify/*_civet_qc.txt 2>/dev/null | head -1)
    if [[ -n "$qc_file" && -f "$qc_file" ]]; then
        # Parse key fields (format varies; best-effort extraction)
        mask_err=$(grep -i "MASK_ERROR" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        wm_pct=$(grep -i "WM_PERCENT" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        gm_pct=$(grep -i "GM_PERCENT" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        csf_pct=$(grep -i "CSF_PERCENT" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        l_inter=$(grep -i "LEFT_INTER" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        r_inter=$(grep -i "RIGHT_INTER" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        l_ss=$(grep -i "LEFT_SURF_SURF" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")
        r_ss=$(grep -i "RIGHT_SURF_SURF" "$qc_file" 2>/dev/null | awk '{print $NF}' || echo "NA")

        echo "${subject},${mask_err},${wm_pct},${gm_pct},${csf_pct},${l_inter},${r_inter},${l_ss},${r_ss}" \
            >> "${QC_DIR}/qc_summary.csv"
    else
        echo "${subject},NA,NA,NA,NA,NA,NA,NA,NA" >> "${QC_DIR}/qc_summary.csv"
    fi

    collected=$((collected + 1))
done

echo ""
echo "=== QC collection summary ==="
echo "Subjects scanned: $total"
echo "QC collected: $collected"
echo "Images: ${QC_DIR}/images/"
echo "Metrics: ${QC_DIR}/metrics/"
echo "Summary: ${QC_DIR}/qc_summary.csv"
