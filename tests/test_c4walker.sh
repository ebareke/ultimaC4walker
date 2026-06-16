#!/usr/bin/env bash
# ===========================================================================
# tests/test_c4walker.sh — dry-run test suite for ultimaC4walker
#
# Exercises the full orchestration (config + sample-sheet parsing, per-assay
# MACS2 flag selection, SE/PE routing, control resolution, HPC job emission,
# validation failures) WITHOUT any bioinformatics tools installed, by asserting
# on `--dry-run` output. Pure bash; runs on bash 3.2+.
#
# Assertions take the haystack as an ARGUMENT (not stdin) so all tallying stays
# in the parent shell — a piped subshell would silently swallow failures.
# ===========================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
C4="$ROOT/bin/c4walker"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0
ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# assert_contains DESC NEEDLE HAYSTACK
assert_contains() {
  case "$3" in *"$2"*) ok "$1" ;; *) bad "$1"; printf '       expected: %s\n' "$2" ;; esac
}
# assert_absent DESC NEEDLE HAYSTACK
assert_absent() {
  case "$3" in *"$2"*) bad "$1"; printf '       unexpected: %s\n' "$2" ;; *) ok "$1" ;; esac
}
lines() { grep "$@" || true; }   # grep that never trips set -e via pipefail

# ---- fixtures -------------------------------------------------------------
CFG="$TMP/config.yaml"
cat > "$CFG" <<EOF
project_name: TestRun
outdir: $TMP/out
run_mode: local
threads: 4
bwa_index: /ref/idx
genome_size: mm
mito_chr: chrM
min_mapq: 20
remove_duplicates: 1
macs2_qval: 0.01
EOF

SAMPLES="$TMP/samples.tsv"
{
  printf 'SAMPLE_ID\tFASTQ1\tFASTQ2\tASSAY\tMARK\tCONTROL_ID\tLIBTYPE\n'
  printf 'k27\t/d/k27_R1.fq.gz\t/d/k27_R2.fq.gz\tCUTTAG\tH3K27me3\tNone\tPE\n'
  printf 'k4\t/d/k4_R1.fq.gz\t/d/k4_R2.fq.gz\tCUTRUN\tH3K4me3\tigg\tPE\n'
  printf 'igg\t/d/igg_R1.fq.gz\t/d/igg_R2.fq.gz\tCUTRUN\tIgG\tNone\tPE\n'
  printf 'tf\t/d/tf_R1.fq.gz\t-\tCHIPSEQ\tCTCF\tinp\tSE\n'
  printf 'inp\t/d/inp_R1.fq.gz\t-\tCHIPSEQ\tInput\tNone\tSE\n'
  printf 'atac\t/d/atac_R1.fq.gz\t/d/atac_R2.fq.gz\tATAC\tNA\tNone\tPE\n'
} > "$SAMPLES"

DRY="$("$C4" run -c "$CFG" -s "$SAMPLES" --dry-run 2>&1)"; rm -rf "$TMP/out"
MACS="$(printf '%s\n' "$DRY" | lines 'callpeak')"

echo "== c4walker dry-run test suite =="

# 1. CLI basics
assert_contains "version prints" "v1.0.0" "$("$C4" version)"
assert_contains "check passes" "sample sheet OK (6 sample(s))" "$("$C4" check -c "$CFG" -s "$SAMPLES" 2>&1)"

# 2. CUT&Tag: broad mark + Tn5 shift, paired-end
K27="$(printf '%s\n' "$MACS" | lines " -n 'k27'")"
assert_contains "CUTTAG H3K27me3 -> --broad"        "--broad"                    "$K27"
assert_contains "CUTTAG -> Tn5 shift -75/150"       "--shift -75 --extsize 150"  "$K27"
assert_contains "CUTTAG paired-end -> BAMPE"        "-f BAMPE"                   "$K27"

# 3. CUT&RUN: narrow with IgG control
K4="$(printf '%s\n' "$MACS" | lines " -n 'k4'")"
assert_contains "CUTRUN k4 -> narrow -q"            "-q 0.01"                        "$K4"
assert_contains "CUTRUN k4 -> uses IgG control"     "-c '$TMP/out/align/igg/igg.filtered" "$K4"

# 4. ChIP-seq: single-end format + input control
assert_absent   "ChIP SE -> single FASTQ only"      "tf_R2"  "$(printf '%s\n' "$DRY" | lines 'bwa mem' | lines 'tf_R1')"
TF="$(printf '%s\n' "$MACS" | lines " -n 'tf'")"
assert_contains "ChIP SE -> -f BAM (not BAMPE)"     "-f BAM " "$TF"
assert_contains "ChIP -> uses input control"        "-c '$TMP/out/align/inp/inp.filtered" "$TF"

# 5. ATAC: Tn5 shift, narrow, NEVER a control
ATAC="$(printf '%s\n' "$MACS" | lines " -n 'atac'")"
assert_contains "ATAC -> shift -100/200"            "--shift -100 --extsize 200" "$ATAC"
assert_absent   "ATAC -> no -c control"             "-c '"                        "$ATAC"
assert_contains "ATAC bigWig -> extendReads"        "--extendReads" "$(printf '%s\n' "$DRY" | lines 'bamCoverage' | lines 'atac')"

# 6. config values propagate
assert_contains "config genome_size propagates"     "-g mm"  "$ATAC"
assert_contains "config min_mapq propagates"        "-q 20"  "$(printf '%s\n' "$DRY" | lines -- '-q 20')"

# 7. HPC: SLURM emits per-sample job scripts that re-invoke the tool
SLURM_CFG="$TMP/slurm.yaml"; sed 's/run_mode: local/run_mode: slurm/' "$CFG" > "$SLURM_CFG"
SLURM_OUT="$("$C4" run -c "$SLURM_CFG" -s "$SAMPLES" --dry-run 2>&1)"
assert_contains "SLURM mode emits sbatch" "sbatch $TMP/out/jobs/slurm/k27.slurm.sh" "$SLURM_OUT"
if [ -f "$TMP/out/jobs/slurm/k27.slurm.sh" ]; then
  assert_contains "SLURM job re-invokes c4walker" 'run-single "k27"' "$(cat "$TMP/out/jobs/slurm/k27.slurm.sh")"
else
  bad "SLURM job re-invokes c4walker"
fi
rm -rf "$TMP/out"

# 8. validation: a bad ASSAY must fail
BAD="$TMP/bad.tsv"
{
  printf 'SAMPLE_ID\tFASTQ1\tFASTQ2\tASSAY\tMARK\tCONTROL_ID\tLIBTYPE\n'
  printf 'x\t/d/x.fq.gz\t-\tWHATEVER\tH3\tNone\tSE\n'
} > "$BAD"
if "$C4" run -c "$CFG" -s "$BAD" --dry-run >/dev/null 2>&1; then bad "invalid ASSAY rejected"; else ok "invalid ASSAY rejected"; fi
rm -rf "$TMP/out"

# 9. --run-single processes exactly one sample
SINGLE="$("$C4" run -c "$CFG" -s "$SAMPLES" --run-single atac --dry-run 2>&1)"; rm -rf "$TMP/out"
assert_contains "--run-single runs one sample" "1" "$(printf '%s\n' "$SINGLE" | grep -c 'sample completed' | tr -d ' ')"

echo
printf '== %d passed, %d failed ==\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
