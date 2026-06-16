# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/signal.sh — coverage tracks (deepTools bamCoverage)
# ---------------------------------------------------------------------------

# c4_bigwig SAMPLE_ID FINAL_BAM ASSAY BW_DIR
c4_bigwig() {
  local sample_id="$1" final_bam="$2" assay="$3" bw_dir="$4"
  local bamcov threads norm extra
  bamcov="$(cfg BAMCOVERAGE bamCoverage)"
  threads="$(cfg THREADS 4)"
  norm="$(cfg BIGWIG_NORM RPKM)"

  if [ "${DRYRUN:-0}" -ne 1 ] && ! have_tool "$bamcov"; then
    log_info "bamCoverage not found; skipping bigWig for $sample_id"
    return 0
  fi

  # ATAC/CUT&Tag benefit from Tn5 read-shift centring of the signal.
  extra=""
  case "$assay" in
    ATAC|CUTTAG) extra="--extendReads $(cfg BIGWIG_EXTEND 150)" ;;
  esac

  local bw="$bw_dir/${sample_id}.${norm}.bw"
  run_cmd "$bamcov -b '$final_bam' -o '$bw' --normalizeUsing $norm \
    --binSize $(cfg BIGWIG_BINSIZE 25) -p $threads $extra"
}
