# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/align.sh — read alignment (BWA-MEM) + coordinate sort + index
# ---------------------------------------------------------------------------

# c4_align SAMPLE_ID FASTQ1 FASTQ2 LIBTYPE OUT_BAM
# Aligns with bwa mem, attaches a read group, sorts and indexes.
c4_align() {
  local sample_id="$1" fastq1="$2" fastq2="$3" libtype="$4" out_bam="$5"

  local bwa samtools threads index rg
  bwa="$(cfg BWA bwa)"
  samtools="$(cfg SAMTOOLS samtools)"
  threads="$(cfg THREADS 4)"
  index="$(cfg BWA_INDEX)"

  [ -n "$index" ] || die "bwa_index not set in config; cannot align $sample_id"

  rg="@RG\tID:${sample_id}\tSM:${sample_id}\tPL:ILLUMINA\tLB:${sample_id}"

  if [ "$libtype" = "PE" ] && [ -n "$fastq2" ] && [ "$fastq2" != "-" ]; then
    run_cmd "$bwa mem -M -t $threads -R '$rg' '$index' '$fastq1' '$fastq2' \
      | $samtools sort -@ $threads -O BAM -o '$out_bam' -"
  else
    run_cmd "$bwa mem -M -t $threads -R '$rg' '$index' '$fastq1' \
      | $samtools sort -@ $threads -O BAM -o '$out_bam' -"
  fi
  run_cmd "$samtools index -@ $threads '$out_bam'"
}
