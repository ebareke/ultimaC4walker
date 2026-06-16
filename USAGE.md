# `ultimaC4walker` — Usage Guide

Complete reference for the v1.0.0 `c4walker` engine and the three run modes.
For an overview, see [`README.md`](README.md).

---

## Contents

1. [Subcommands](#subcommands)
2. [`run` — the full pipeline](#run--the-full-pipeline)
3. [Sample sheet schema](#sample-sheet-schema)
4. [Configuration reference](#configuration-reference)
5. [Per-assay behaviour](#per-assay-behaviour)
6. [Run modes (local / SLURM / PBS)](#run-modes-local--slurm--pbs)
7. [Output directory layout](#output-directory-layout)
8. [Running via Docker](#running-via-docker)
9. [Running via Apptainer](#running-via-apptainer)
10. [Running via Nextflow](#running-via-nextflow)
11. [Environment variables](#environment-variables)
12. [Recipes](#recipes)
13. [Exit behaviour](#exit-behaviour)

---

## Subcommands

| Subcommand | Purpose |
|------------|---------|
| `run`      | End-to-end pipeline: align → filter → peaks → QC → MultiQC |
| `check`    | Validate a config + sample sheet without running anything |
| `version`  | Print the version |
| `help`     | Show usage |

```text
c4walker run   -c CONFIG -s SAMPLES [--run-single ID] [--dry-run]
c4walker check -c CONFIG -s SAMPLES
c4walker version
```

---

## `run` — the full pipeline

| Flag | Description |
|------|-------------|
| `-c, --config FILE`  | YAML config (see [config/config.yaml](config/config.yaml)) — **required** |
| `-s, --samples FILE` | Tab-delimited sample sheet — **required** |
| `--run-single ID`    | Process only one `SAMPLE_ID` (used internally by HPC job scripts) |
| `--dry-run`          | Print every command instead of executing it (no tools required) |
| `-h, --help`         | Show help |

Per sample, `run` performs:

1. **FastQC** on each FASTQ.
2. **BWA-MEM** alignment (read group attached) → coordinate-sorted, indexed BAM.
3. **Filtering**: optional chromosome whitelist → mitochondrial removal →
   MAPQ threshold → ENCODE-blacklist subtraction.
4. **Duplicates**: Picard metrics (informational) + `samtools markdup` removal.
5. **Alignment QC**: `idxstats`, `flagstat`, `stats`.
6. **MACS3** peak calling (assay-aware, see below; MACS2-compatible — set
   `macs2:` in the config to force MACS2) + **FRiP**.
7. **bigWig** coverage track (deepTools `bamCoverage`).
8. **Fragment size** (paired-end, deepTools), **preseq** library complexity,
   **phantompeakqualtools** cross-correlation (NSC/RSC).

After all samples (local mode), a single **MultiQC** report aggregates everything.

Optional tools (Picard, preseq, deepTools, phantompeak, MultiQC) degrade
gracefully: if absent they are logged and skipped. The five required tools are
`bwa`, `samtools`, `bedtools`, `macs3` (or `macs2`), `fastqc` (checks are skipped
under `--dry-run`).

---

## Sample sheet schema

Tab-delimited, header required:

```tsv
SAMPLE_ID	FASTQ1	FASTQ2	ASSAY	MARK	CONTROL_ID	LIBTYPE
```

| Column | Values / meaning |
|--------|------------------|
| `SAMPLE_ID`  | Unique sample name (used for all output paths) |
| `FASTQ1`     | Path to R1 FASTQ (gzip OK) |
| `FASTQ2`     | Path to R2 FASTQ, or `-` for single-end |
| `ASSAY`      | `CHIPSEQ` \| `CUTRUN` \| `CUTTAG` \| `ATAC` (case-insensitive) |
| `MARK`       | Antibody / target, e.g. `H3K27me3`, `CTCF`, `IgG`, `NA` |
| `CONTROL_ID` | `SAMPLE_ID` of the input/IgG control, or `None` |
| `LIBTYPE`    | `PE` \| `SE` (case-insensitive) |

`check` validates ASSAY, LIBTYPE and non-empty FASTQ1 for every row and reports
all problems at once.

---

## Configuration reference

Flat `key: value` YAML — nested maps and lists are intentionally unsupported.
CLI flags override config. Full annotated example:
[config/config.yaml](config/config.yaml).

| Key | Default | Meaning |
|-----|---------|---------|
| `project_name` | `c4walker` | Label used in HPC job names |
| `outdir` | `./c4walker_out` | Output root |
| `run_mode` | `local` | `local` \| `slurm` \| `pbs` |
| `threads` | `4` | Threads per step |
| `bwa_index` | — | BWA index prefix (**required to align**) |
| `genome_size` | `hs` | MACS2 `-g` (`hs`/`mm`/`ce`/`dm` or a number) |
| `mito_chr` | `chrM` | Mitochondrial contig to drop (empty = keep) |
| `chroms_keep_list` | — | File of chromosomes to keep (one per line) |
| `blacklist_bed` | — | ENCODE blacklist BED to subtract |
| `min_mapq` | `30` | Minimum mapping quality |
| `remove_duplicates` | `1` | `1` remove, `0` keep |
| `macs2_qval` | `0.01` | Narrow-peak q-value |
| `macs2_broad_qval` | `0.1` | Broad-mark cutoff |
| `shift_extend_cuttag` | `--nomodel --shift -75 --extsize 150` | CUT&Tag Tn5 params |
| `shift_extend_atac` | `--nomodel --shift -100 --extsize 200` | ATAC Tn5 params |
| `shift_extend_cutrun` | `""` | Extra CUT&RUN MACS2 params |
| `bigwig_norm` | `RPKM` | deepTools normalization |
| `bigwig_binsize` | `25` | bigWig bin size |
| `bigwig_extend` | `150` | Read extension for ATAC/CUT&Tag tracks |
| `macs3` / `macs2` | `macs3` | MACS binary (MACS3 preferred; set `macs2:` to force MACS2) |
| `bwa`/`samtools`/`bedtools`/`fastqc`/`bamcoverage`/`multiqc`/`picard`/`rscript` | bare name | Tool paths/overrides |
| `phantompeak_rscript` | `""` | Path to `run_spp.R` (enables NSC/RSC) |
| `slurm_partition`/`slurm_time`/`slurm_mem` | `general`/`24:00:00`/`32G` | SLURM defaults |
| `pbs_queue`/`pbs_time`/`pbs_mem` | `batch`/`24:00:00`/`32gb` | PBS defaults |

---

## Per-assay behaviour

| Assay | MACS2 mode | Control | Tn5 shift | bigWig extend |
|-------|------------|---------|-----------|---------------|
| `CHIPSEQ` | narrow (broad for repressive marks) | input (if set) | none | no |
| `CUTRUN`  | narrow (broad for repressive marks) | IgG (if set) | none | no |
| `CUTTAG`  | narrow (broad for repressive marks) | IgG (if set) | `--shift -75 --extsize 150` | yes |
| `ATAC`    | narrow (broad for repressive marks) | **never** | `--shift -100 --extsize 200` | yes |

Marks matched as **broad** (→ MACS2 `--broad`): `H3K27me3`, `H3K9me3`,
`H3K36me3`, `H4K20me*`. Paired-end samples use `-f BAMPE`; single-end use
`-f BAM`.

---

## Run modes (local / SLURM / PBS)

* **local** — processes every sample in the current shell, then runs MultiQC.
* **slurm** — writes `outdir/jobs/slurm/<sample>.slurm.sh` per sample and
  `sbatch`-submits each; each job re-invokes `c4walker run --run-single`.
* **pbs** — same with `outdir/jobs/pbs/<sample>.pbs.sh` and `qsub`.

Set the mode in config (`run_mode:`). Combine with `--dry-run` to preview the
exact `sbatch`/`qsub` commands and inspect the generated job scripts.

---

## Output directory layout

```
outdir/
├── align/<sample>/    *.sorted.bam, intermediate + *.filtered[.nodup].bam(.bai)
├── peaks/<sample>/    <sample>_peaks.narrowPeak|broadPeak, *.bdg, summits
├── bigwig/<sample>/   <sample>.<norm>.bw
├── qc/<sample>/       *_fastqc.*, idxstats/flagstat/stats, frip, fragsize,
│                      preseq, picard metrics, spp (NSC/RSC)
├── logs/              HPC stdout/stderr
├── jobs/{slurm,pbs}/  generated job scripts (HPC modes)
└── multiqc/           multiqc_report.html (local mode)
```

---

## Running via Docker

```bash
docker build -t ultimac4walker:1.0.0 .
docker run --rm -v "$PWD":/data ultimac4walker:1.0.0 \
    run -c /data/config/config.container.yaml -s /data/config/samples.tsv
```

The image bundles every tool; only your data and genome resources need mounting.

---

## Running via Apptainer

```bash
apptainer build c4walker.sif docker-daemon://ultimac4walker:1.0.0
apptainer run -B "$PWD":/data c4walker.sif \
    run -c /data/config/config.container.yaml -s /data/config/samples.tsv
```

See [containers/README.md](containers/README.md).

---

## Running via Nextflow

```bash
nextflow run nextflow/main.nf \
    --samplesheet samples.csv --fasta genome.fa \
    --blacklist hg38-blacklist.bed --genome_size hs \
    --outdir results -profile docker
```

The Nextflow sample sheet is CSV (`sample,assay,mark,fastq_1,fastq_2`). See
[nextflow/README.md](nextflow/README.md).

---

## Environment variables

| Variable | Effect |
|----------|--------|
| `C4_LIBDIR` | Override the `lib/` location (set in the container) |
| `C4_NO_COLOR` | Disable coloured log output |
| `C4WALKER_BIN` | Path to the `c4walker` binary used by `example/run_example.sh` |

---

## Recipes

### CUT&Tag H3K27me3 (broad, Tn5)

```tsv
SAMPLE_ID	FASTQ1	FASTQ2	ASSAY	MARK	CONTROL_ID	LIBTYPE
k27_r1	k27_R1.fq.gz	k27_R2.fq.gz	CUTTAG	H3K27me3	None	PE
```

```bash
c4walker run -c config/config.yaml -s samples.tsv
```

### ChIP-seq TF with input control (single-end)

```tsv
ctcf	ctcf_R1.fq.gz	-	CHIPSEQ	CTCF	input	SE
input	input_R1.fq.gz	-	CHIPSEQ	Input	None	SE
```

### ATAC-seq (paired-end, no control)

```tsv
atac_r1	atac_R1.fq.gz	atac_R2.fq.gz	ATAC	NA	None	PE
```

### Preview an HPC submission

```bash
# set run_mode: slurm in the config
c4walker run -c config/config.yaml -s samples.tsv --dry-run
```

### Re-run one failed sample

```bash
c4walker run -c config/config.yaml -s samples.tsv --run-single atac_r1
```

---

## Exit behaviour

`c4walker` runs under `set -euo pipefail`: any tool failure aborts the run with
a non-zero exit and a `[FAIL]` message. Validation problems (bad ASSAY/LIBTYPE,
missing files, unknown run mode) fail fast before any work begins. Optional-tool
absences are warnings, not errors.
