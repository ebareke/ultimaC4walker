#!/usr/bin/env bash
#
# End-to-end example for ultimaC4walker.
#
# 1. Generates a tiny synthetic genome + enriched paired-end reads for a
#    CUT&Tag and an ATAC sample (example/scripts/make_synthetic.py).
# 2. Builds a BWA index of the synthetic reference.
# 3. Runs c4walker on both samples.
#
# If the bioinformatics tools (bwa, macs2, ...) are not installed it falls
# back to `--dry-run`, which prints every command without executing it, so the
# example always demonstrates the orchestration. For the real run, use the
# container, which bundles every tool:
#
#   docker run --rm -v "$PWD":/data ultimac4walker:1.0.0 \
#       run -c /data/example/data/config.yaml -s /data/example/data/samples.tsv
#
# Requirements (real run): bwa, samtools, macs2, fastqc, python3.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DATA="$HERE/data"
C4="${C4WALKER_BIN:-$ROOT/bin/c4walker}"

echo ">> [1/3] Generating synthetic dataset"
python3 "$HERE/scripts/make_synthetic.py"

# Decide whether we can do a real run.
DRY=""
if ! command -v bwa >/dev/null 2>&1 || ! command -v macs2 >/dev/null 2>&1; then
  echo ">> bwa/macs2 not found — running in --dry-run mode."
  echo ">> (use the container for a real end-to-end run; see header)"
  DRY="--dry-run"
fi

INDEX_PREFIX="$DATA/bwa/ref"
if [ -z "$DRY" ]; then
  echo ">> [2/3] Building BWA index"
  mkdir -p "$DATA/bwa"
  bwa index -p "$INDEX_PREFIX" "$DATA/reference.fa"
else
  echo ">> [2/3] Skipping BWA index (dry-run)"
fi

cat > "$DATA/config.yaml" <<EOF
project_name: c4walker_example
outdir: $HERE/results
run_mode: local
threads: 2
bwa_index: $INDEX_PREFIX
genome_size: 10000
mito_chr: ""
min_mapq: 0
remove_duplicates: 1
macs2_qval: 0.05
EOF

echo ">> [3/3] Running c4walker"
"$C4" run -c "$DATA/config.yaml" -s "$DATA/samples.tsv" $DRY

echo
if [ -z "$DRY" ]; then
  echo ">> Done. Key outputs under $HERE/results :"
  echo "   peaks/cuttag_rep1/cuttag_rep1_peaks.*"
  echo "   peaks/atac_rep1/atac_rep1_peaks.narrowPeak"
  echo "   qc/*/*.frip.txt"
  echo "   multiqc/multiqc_report.html"
else
  echo ">> Dry-run complete — every command was printed above, nothing executed."
fi
