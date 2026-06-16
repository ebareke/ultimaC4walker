# Example — end-to-end in seconds

A self-contained demonstration of ultimaC4walker on a tiny synthetic genome
with two samples — a **CUT&Tag** (H3K4me3) and an **ATAC-seq** library — whose
reads are enriched over defined "peak" windows so MACS2 has real signal to
call.

## 1. Standalone tool

```bash
bash example/run_example.sh
```

It will:

1. generate `data/reference.fa`, enriched paired-end FASTQ, `samples.tsv` and
   `samplesheet.csv` (`scripts/make_synthetic.py`);
2. build a BWA index of the synthetic reference;
3. run `c4walker run` on both samples.

If `bwa` / `macs2` are not installed, the script automatically switches to
`--dry-run` (prints every command without executing) so the example still
works. For a real run with no local installs, use the container:

```bash
docker run --rm -v "$PWD":/data ultimac4walker:1.0.0 \
    run -c /data/example/data/config.yaml -s /data/example/data/samples.tsv
```

Expected real-run result: a `*_peaks.narrowPeak` / `*_peaks.broadPeak` over
each enriched window, plus per-sample FRiP and a MultiQC report.

## 2. FASTQ → peaks (Nextflow)

Needs Nextflow and a container engine; the tools are bundled in the image.

```bash
python3 example/scripts/make_synthetic.py     # reference + reads + samplesheet
nextflow run nextflow/main.nf -profile test -stub      # topology check, no tools
nextflow run nextflow/main.nf -profile test,docker     # real end-to-end
```

## Files

```
scripts/make_synthetic.py    reference + enriched FASTQ + sample sheets
run_example.sh               standalone driver (real run or auto dry-run)
data/                        generated inputs (git-ignored; reproduced by the script)
results/                     generated outputs (git-ignored)
```

Generated artifacts are git-ignored — `make_synthetic.py` reproduces them
deterministically (fixed seed).
