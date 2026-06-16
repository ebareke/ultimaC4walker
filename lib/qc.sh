# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/qc.sh — quality-control modules
#
# FastQC, samtools stats/idxstats, deepTools fragment sizes, preseq library
# complexity, phantompeakqualtools cross-correlation, and a final MultiQC
# aggregation. Optional tools degrade gracefully (logged, skipped).
# ---------------------------------------------------------------------------

# c4_fastqc FASTQ1 FASTQ2 LIBTYPE QC_DIR
c4_fastqc() {
  local fastq1="$1" fastq2="$2" libtype="$3" qc_dir="$4"
  local fastqc threads
  fastqc="$(cfg FASTQC fastqc)"
  threads="$(cfg THREADS 4)"
  run_cmd "$fastqc -t $threads -o '$qc_dir' '$fastq1'"
  if [ "$libtype" = "PE" ] && [ -n "$fastq2" ] && [ "$fastq2" != "-" ]; then
    run_cmd "$fastqc -t $threads -o '$qc_dir' '$fastq2'"
  fi
}

# c4_align_qc SAMPLE_ID FINAL_BAM QC_DIR  (samtools stats + idxstats)
c4_align_qc() {
  local sample_id="$1" final_bam="$2" qc_dir="$3"
  local samtools threads
  samtools="$(cfg SAMTOOLS samtools)"
  threads="$(cfg THREADS 4)"
  run_cmd "$samtools idxstats '$final_bam' > '$qc_dir/${sample_id}.idxstats.txt'"
  run_cmd "$samtools flagstat -@ $threads '$final_bam' > '$qc_dir/${sample_id}.flagstat.txt'"
  run_cmd "$samtools stats -@ $threads '$final_bam' > '$qc_dir/${sample_id}.stats.txt'"
}

# c4_fragment_size SAMPLE_ID FINAL_BAM LIBTYPE QC_DIR (PE only; deepTools)
c4_fragment_size() {
  local sample_id="$1" final_bam="$2" libtype="$3" qc_dir="$4"
  [ "$libtype" = "PE" ] || return 0
  if [ "${DRYRUN:-0}" -ne 1 ] && ! have_tool bamPEFragmentSize; then
    log_info "bamPEFragmentSize not found; skipping fragment-size QC for $sample_id"
    return 0
  fi
  local threads; threads="$(cfg THREADS 4)"
  run_cmd "bamPEFragmentSize -b '$final_bam' \
    --histogram '$qc_dir/${sample_id}.fragsize.png' \
    -T '${sample_id} fragment size' --samplesLabel '$sample_id' \
    -p $threads --outRawFragmentLengths '$qc_dir/${sample_id}.fragsize.tsv' \
    > '$qc_dir/${sample_id}.fragsize.summary.txt'"
}

# c4_preseq SAMPLE_ID FINAL_BAM ALIGN_DIR QC_DIR (library complexity)
c4_preseq() {
  local sample_id="$1" final_bam="$2" align_dir="$3" qc_dir="$4"
  if [ "${DRYRUN:-0}" -ne 1 ] && ! have_tool preseq; then
    log_info "preseq not found; skipping library complexity for $sample_id"
    return 0
  fi
  local samtools threads
  samtools="$(cfg SAMTOOLS samtools)"
  threads="$(cfg THREADS 4)"
  local ns="$align_dir/${sample_id}.preseq.ns.bam"
  run_cmd "$samtools sort -n -@ $threads -O BAM -o '$ns' '$final_bam'"
  run_cmd "preseq lc_extrap -B -P -o '$qc_dir/${sample_id}.preseq_lc_extrap.txt' '$ns' || true"
  run_cmd "rm -f '$ns'"
}

# c4_phantompeak SAMPLE_ID FINAL_BAM LIBTYPE QC_DIR (NSC/RSC cross-correlation)
c4_phantompeak() {
  local sample_id="$1" final_bam="$2" libtype="$3" qc_dir="$4"
  local rscript run_spp threads
  rscript="$(cfg RSCRIPT Rscript)"
  run_spp="$(cfg PHANTOMPEAK_RSCRIPT)"
  threads="$(cfg THREADS 4)"
  [ -n "$run_spp" ] || { log_info "phantompeak_rscript not configured; skipping cross-correlation for $sample_id"; return 0; }
  if [ "${DRYRUN:-0}" -ne 1 ] && ! have_tool "$rscript"; then
    log_info "Rscript not found; skipping cross-correlation for $sample_id"
    return 0
  fi
  local out="$qc_dir/${sample_id}.spp.txt"
  local pdf="$qc_dir/${sample_id}.spp.pdf"
  run_cmd "$rscript '$run_spp' -c='$final_bam' -p=$threads -savp='$pdf' -out='$out'"
}

# c4_multiqc OUTDIR  (final aggregation across all per-sample QC)
c4_multiqc() {
  local outdir="$1"
  local multiqc; multiqc="$(cfg MULTIQC multiqc)"
  if [ "${DRYRUN:-0}" -ne 1 ] && ! have_tool "$multiqc"; then
    log_info "multiqc not found; skipping aggregate report"
    return 0
  fi
  run_cmd "$multiqc '$outdir' -o '$outdir/multiqc' -n multiqc_report -f"
}
