# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/filter.sh — post-alignment filtering
#
# Chromosome whitelist -> mitochondrial removal -> MAPQ -> ENCODE blacklist
# -> duplicate marking/removal (samtools markdup). Each stage is optional and
# driven by config; the chosen final BAM path is echoed on stdout so the
# caller can capture it.
# ---------------------------------------------------------------------------

# c4_filter SAMPLE_ID IN_BAM ALIGN_DIR QC_DIR  -> echoes final BAM path
c4_filter() {
  local sample_id="$1" in_bam="$2" align_dir="$3" qc_dir="$4"

  local samtools bedtools threads
  samtools="$(cfg SAMTOOLS samtools)"
  bedtools="$(cfg BEDTOOLS bedtools)"
  threads="$(cfg THREADS 4)"

  local chroms_keep mito_chr blacklist min_mapq remove_dup picard
  chroms_keep="$(cfg CHROMS_KEEP_LIST)"
  mito_chr="$(cfg MITO_CHR chrM)"
  blacklist="$(cfg BLACKLIST_BED)"
  min_mapq="$(cfg MIN_MAPQ 30)"
  remove_dup="$(cfg REMOVE_DUPLICATES 1)"
  picard="$(cfg PICARD picard)"

  local cur="$in_bam"

  # 1. Keep only whitelisted chromosomes.
  if [ -n "$chroms_keep" ] && [ -f "$chroms_keep" ]; then
    local bam_chrom="$align_dir/${sample_id}.chrom.bam"
    local chroms; chroms="$(tr '\n' ' ' < "$chroms_keep")"
    run_cmd "$samtools view -bh -@ $threads '$cur' $chroms > '$bam_chrom'"
    run_cmd "$samtools index -@ $threads '$bam_chrom'"
    cur="$bam_chrom"
  fi

  # 2. Drop the mitochondrial contig.
  if [ -n "$mito_chr" ]; then
    local bam_nomito="$align_dir/${sample_id}.nomito.bam"
    run_cmd "$samtools idxstats '$cur' | cut -f1 | grep -vw '$mito_chr' \
      | xargs $samtools view -b -@ $threads '$cur' > '$bam_nomito'"
    run_cmd "$samtools index -@ $threads '$bam_nomito'"
    cur="$bam_nomito"
  fi

  # 3. MAPQ filter.
  local bam_mapq="$align_dir/${sample_id}.mapq.bam"
  run_cmd "$samtools view -b -@ $threads -q $min_mapq '$cur' > '$bam_mapq'"
  run_cmd "$samtools index -@ $threads '$bam_mapq'"
  cur="$bam_mapq"

  # 4. ENCODE blacklist subtraction.
  if [ -n "$blacklist" ] && [ -f "$blacklist" ]; then
    local bam_bl="$align_dir/${sample_id}.blacklisted.bam"
    run_cmd "$bedtools intersect -v -abam '$cur' -b '$blacklist' > '$bam_bl'"
    run_cmd "$samtools index -@ $threads '$bam_bl'"
    cur="$bam_bl"
  fi

  # 5. Picard duplication metrics (informational; on pre-dedup BAM).
  if [ "${DRYRUN:-0}" -eq 1 ] || have_tool "${picard%% *}"; then
    local dupmetrics="$qc_dir/${sample_id}.picard_dup_metrics.txt"
    run_cmd "$picard MarkDuplicates I='$cur' O=/dev/null M='$dupmetrics' \
      ASSUME_SORTED=true VALIDATION_STRINGENCY=SILENT QUIET=true"
  else
    log_info "picard not found; skipping duplication metrics for $sample_id"
  fi

  # 6. Mark/remove duplicates with samtools markdup (name-sort -> fixmate ->
  #    coord-sort -> markdup).
  if [ "$remove_dup" -eq 1 ]; then
    local ns="$align_dir/${sample_id}.namesort.bam"
    local fx="$align_dir/${sample_id}.fixmate.bam"
    local cs="$align_dir/${sample_id}.coordsort.bam"
    local nodup="$align_dir/${sample_id}.filtered.nodup.bam"
    run_cmd "$samtools sort -n -@ $threads -O BAM -o '$ns' '$cur'"
    run_cmd "$samtools fixmate -m -@ $threads '$ns' '$fx'"
    run_cmd "$samtools sort -@ $threads -O BAM -o '$cs' '$fx'"
    run_cmd "$samtools markdup -r -@ $threads '$cs' '$nodup'"
    run_cmd "$samtools index -@ $threads '$nodup'"
    run_cmd "rm -f '$ns' '$fx' '$cs'"
    cur="$nodup"
  else
    local final="$align_dir/${sample_id}.filtered.bam"
    run_cmd "cp '$cur' '$final'"
    run_cmd "$samtools index -@ $threads '$final'"
    cur="$final"
  fi

  printf '%s' "$cur"
}
