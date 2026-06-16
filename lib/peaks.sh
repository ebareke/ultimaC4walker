# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/peaks.sh — assay-aware MACS2 peak calling + FRiP scoring
#
# Supports four chromatin assays:
#   CHIPSEQ  classic transcription-factor / histone ChIP (uses input control)
#   CUTRUN   CUT&RUN              (no shift; IgG control optional)
#   CUTTAG   CUT&Tag              (Tn5: --shift -75 --extsize 150 --nomodel)
#   ATAC     ATAC-seq             (Tn5: --shift -100 --extsize 200 --nomodel,
#                                  never uses a control)
# Broad marks (H3K27me3, H3K9me3, H3K36me3) switch MACS2 to --broad.
# ---------------------------------------------------------------------------

# c4_macs_bin -> resolve the MACS binary. Prefers MACS3 (maintained, glibc-safe,
# MACS2-compatible CLI); honours an explicit `macs3:`/`macs2:` config override.
c4_macs_bin() {
  local m
  m="$(cfg MACS3 "$(cfg MACS2 "")")"
  if [ -n "$m" ]; then printf '%s' "$m"; return 0; fi
  if have_tool macs3; then printf 'macs3'
  elif have_tool macs2; then printf 'macs2'
  else printf 'macs3'; fi
}

# c4_macs2_opts ASSAY MARK LIBTYPE  -> echoes the MACS option string
c4_macs2_opts() {
  local assay="$1" mark="$2" libtype="$3"

  local format="BAM"
  [ "$libtype" = "PE" ] && format="BAMPE"

  local gsize qval broad_cut
  gsize="$(cfg GENOME_SIZE hs)"
  qval="$(cfg MACS2_QVAL 0.01)"
  broad_cut="$(cfg MACS2_BROAD_QVAL 0.1)"

  # Broad histone marks.
  local broad=0
  case "$mark" in
    *H3K27me3*|*H3K9me3*|*H3K36me3*|*H4K20me*) broad=1 ;;
  esac

  # Assay-specific Tn5 shift/extend.
  local extra=""
  case "$assay" in
    CUTTAG) extra="$(cfg SHIFT_EXTEND_CUTTAG "--nomodel --shift -75 --extsize 150")" ;;
    ATAC)   extra="$(cfg SHIFT_EXTEND_ATAC   "--nomodel --shift -100 --extsize 200")" ;;
    CUTRUN) extra="$(cfg SHIFT_EXTEND_CUTRUN "")" ;;
    *)      extra="" ;;
  esac

  if [ "$broad" -eq 1 ]; then
    printf -- '-f %s -g %s --bdg --broad --broad-cutoff %s %s' \
      "$format" "$gsize" "$broad_cut" "$extra"
  else
    printf -- '-f %s -g %s --bdg -q %s %s' \
      "$format" "$gsize" "$qval" "$extra"
  fi
}

# c4_resolve_control CONTROL_ID OUTDIR  -> echoes "-c '<bam>'" or "" (ATAC: "")
c4_resolve_control() {
  local control_id="$1" outdir="$2"
  case "$control_id" in
    ''|None|none|NONE|NA|-) printf ''; return 0 ;;
  esac
  local cbam="$outdir/align/$control_id/${control_id}.filtered.nodup.bam"
  [ -f "$cbam" ] || cbam="$outdir/align/$control_id/${control_id}.filtered.bam"
  if [ -f "$cbam" ] || [ "${DRYRUN:-0}" -eq 1 ]; then
    printf -- "-c '%s'" "$cbam"
  else
    log_warn "control BAM for '$control_id' not found; calling peaks without control"
    printf ''
  fi
}

# c4_callpeak SAMPLE_ID FINAL_BAM ASSAY MARK CONTROL_ID LIBTYPE OUTDIR PEAKS_DIR
c4_callpeak() {
  local sample_id="$1" final_bam="$2" assay="$3" mark="$4"
  local control_id="$5" libtype="$6" outdir="$7" peaks_dir="$8"

  local macs2; macs2="$(c4_macs_bin)"
  local opts control_arg
  opts="$(c4_macs2_opts "$assay" "$mark" "$libtype")"

  # ATAC-seq never uses a control track.
  if [ "$assay" = "ATAC" ]; then
    control_arg=""
  else
    control_arg="$(c4_resolve_control "$control_id" "$outdir")"
  fi

  run_cmd "$macs2 callpeak -t '$final_bam' $control_arg -n '$sample_id' \
    $opts --outdir '$peaks_dir'"
}

# c4_frip SAMPLE_ID FINAL_BAM PEAKS_DIR QC_DIR
c4_frip() {
  local sample_id="$1" final_bam="$2" peaks_dir="$3" qc_dir="$4"
  local samtools bedtools
  samtools="$(cfg SAMTOOLS samtools)"
  bedtools="$(cfg BEDTOOLS bedtools)"

  local peaks=""
  if [ -f "$peaks_dir/${sample_id}_peaks.narrowPeak" ]; then
    peaks="$peaks_dir/${sample_id}_peaks.narrowPeak"
  elif [ -f "$peaks_dir/${sample_id}_peaks.broadPeak" ]; then
    peaks="$peaks_dir/${sample_id}_peaks.broadPeak"
  fi

  if [ "${DRYRUN:-0}" -eq 1 ]; then
    run_cmd "compute FRiP for $sample_id -> $qc_dir/${sample_id}.frip.txt"
    return 0
  fi
  [ -n "$peaks" ] || { log_warn "no peak file for FRiP ($sample_id)"; return 0; }

  local total in_peaks frip
  total="$($samtools view -c "$final_bam")"
  in_peaks="$($bedtools intersect -u -abam "$final_bam" -b "$peaks" | $samtools view -c -)"
  if [ "$total" -gt 0 ]; then
    frip="$(awk -v a="$in_peaks" -v b="$total" 'BEGIN{printf "%.6f", a/b}')"
    {
      printf 'sample\ttotal_reads\treads_in_peaks\tFRiP\n'
      printf '%s\t%s\t%s\t%s\n' "$sample_id" "$total" "$in_peaks" "$frip"
    } > "$qc_dir/${sample_id}.frip.txt"
    log_ok "FRiP($sample_id) = $frip"
  fi
}
