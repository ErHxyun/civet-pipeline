#!/bin/bash
# =============================================================================
# Checkpoint utility: verify inputs before running or outputs after running
# =============================================================================
# Usage:
#   bash check_status.sh pre  <subjects_dir> <required_pattern> [<required_pattern2> ...]
#   bash check_status.sh post <subjects_dir> <expected_pattern> [<expected_pattern2> ...]
#
# Examples:
#   # Pre-run: check BIDS subjects have anat and func
#   bash check_status.sh pre /data/BIDS "anat/*T1w.nii.gz" "func/*bold.nii.gz"
#
#   # Post-run: check fMRIPrep outputs exist
#   bash check_status.sh post /data/fmriprep_out "fmriprep/sub-*/anat/*preproc_T1w.nii.gz"
#
#   # Post-run: check for success message in logs
#   bash check_status.sh post-log /data/logs "fMRIPrep finished successfully!"
# =============================================================================

set -euo pipefail

MODE="${1:?Usage: check_status.sh <pre|post|post-log> <directory> <pattern> [pattern...]}"
BASE_DIR="${2:?Missing directory argument}"
shift 2
PATTERNS=("$@")

if [[ ${#PATTERNS[@]} -eq 0 ]]; then
    echo "ERROR: At least one pattern required"
    exit 1
fi

if [[ ! -d "$BASE_DIR" ]]; then
    echo "ERROR: Directory not found: $BASE_DIR"
    exit 1
fi

total=0
pass=0
fail=0
fail_list=()

if [[ "$MODE" == "post-log" ]]; then
    # Check log files for a success message
    success_pattern="${PATTERNS[0]}"
    for logfile in "$BASE_DIR"/*.out; do
        [[ -f "$logfile" ]] || continue
        total=$((total + 1))
        subject=$(basename "$logfile" .out)
        if tail -n 30 "$logfile" | grep -q "$success_pattern"; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            fail_list+=("$subject")
        fi
    done
else
    # Check file patterns under each subject directory
    for subj_dir in "$BASE_DIR"/sub-*/ "$BASE_DIR"/*/; do
        [[ -d "$subj_dir" ]] || continue
        # Skip non-subject dirs like fsaverage
        dirname=$(basename "$subj_dir")
        [[ "$dirname" == sub-* ]] || [[ "$MODE" == "post" ]] || continue

        total=$((total + 1))
        subject=$(basename "$subj_dir")
        all_found=true

        for pattern in "${PATTERNS[@]}"; do
            matches=$(find "$subj_dir" -path "*${pattern}" 2>/dev/null | head -1)
            if [[ -z "$matches" ]]; then
                all_found=false
                break
            fi
        done

        if $all_found; then
            pass=$((pass + 1))
        else
            fail=$((fail + 1))
            fail_list+=("$subject")
        fi
    done
fi

# Report
echo "============================================"
echo "Checkpoint: $MODE"
echo "Directory:  $BASE_DIR"
echo "Patterns:   ${PATTERNS[*]}"
echo "============================================"
echo "Total:    $total"
echo "Passed:   $pass"
echo "Failed:   $fail"

if [[ $fail -gt 0 ]]; then
    echo ""
    echo "Failed subjects (first 20):"
    for subj in "${fail_list[@]:0:20}"; do
        echo "  - $subj"
    done
    if [[ $fail -gt 20 ]]; then
        echo "  ... and $((fail - 20)) more"
    fi
fi

echo "============================================"

if [[ "$MODE" == "pre" && $fail -gt 0 ]]; then
    echo "WARNING: $fail subjects missing required inputs."
    echo "These subjects will be skipped during processing."
fi

exit 0
