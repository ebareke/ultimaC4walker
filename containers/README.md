# Container images

Both images bundle **c4walker** plus the full toolchain (bwa, samtools,
bedtools, MACS3, FastQC, Picard, preseq, deepTools, phantompeakqualtools,
MultiQC), so a single container runs the entire **FASTQ → peaks/QC** workflow
for ChIP-seq, CUT&RUN, CUT&Tag and ATAC-seq.

## Docker

```bash
# Build (from the repository root)
docker build -t ultimac4walker:1.0.0 .

# Run on your data (mount the working dir at /data)
docker run --rm -v "$PWD":/data ultimac4walker:1.0.0 \
    run -c /data/config.container.yaml -s /data/samples.tsv

# Dry-run (prints commands; no tools invoked)
docker run --rm -v "$PWD":/data ultimac4walker:1.0.0 \
    run -c /data/config.container.yaml -s /data/samples.tsv --dry-run
```

Published image (after a tagged release): `ghcr.io/ebareke/ultimac4walker:1.0.0`.

## Apptainer / Singularity (HPC)

```bash
# Option A — from the published image
apptainer build c4walker.sif containers/c4walker.def

# Option B — from a locally-built Docker image, no registry needed
docker build -t ultimac4walker:1.0.0 .
apptainer build c4walker.sif docker-daemon://ultimac4walker:1.0.0

# Run
apptainer run -B "$PWD":/data c4walker.sif \
    run -c /data/config.container.yaml -s /data/samples.tsv
```

## Image contents

| Tool                  | Version  | Purpose                                  |
|-----------------------|----------|------------------------------------------|
| c4walker              | 1.0.0    | Workflow driver                          |
| bwa                   | 0.7.17   | Short-read alignment                     |
| samtools              | 1.19     | BAM sort/index/filter/markdup            |
| bedtools              | 2.31.1   | Blacklist subtraction, FRiP intersect    |
| MACS3                 | 3.0.4    | Peak calling (narrow/broad/Tn5)          |
| FastQC                | 0.12.1   | Read-level QC                            |
| Picard                | 3.1.1    | Duplication metrics                      |
| preseq                | 3.2.0    | Library complexity                       |
| deepTools             | 3.5.5    | bigWig coverage, fragment size           |
| phantompeakqualtools  | 1.2.2    | NSC / RSC cross-correlation              |
| MultiQC               | 1.21     | Aggregate report                         |

The driver is plain Bash; you can also run it outside the container with the
matching tools installed (see `environment.yml`).
