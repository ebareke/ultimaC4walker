# Roadmap

This roadmap is indicative, not a commitment. Items move as real-world datasets
and user feedback dictate.

## Near term

- **Published images** on GHCR and Docker Hub on every tagged release, plus a
  pre-built Apptainer SIF as an `oras://` artifact, so no local build is needed.
- **Consensus / replicate handling** — IDR across replicate peak sets and a
  merged high-confidence peak set per condition.
- **Spike-in normalization** (e.g. *Drosophila* / *E. coli* carry-over) for
  CUT&RUN / CUT&Tag quantitative scaling of bigWig tracks.
- **Differential binding** hand-off (DiffBind / csaw-ready count matrices over a
  consensus peak set).

## Considered

- **Alternative aligners** (Bowtie2) selectable per run.
- **Fragment-size–aware ATAC sub-tracks** (nucleosome-free / mono / di) split by
  insert size.
- **TSS enrichment & FRiP gates** that flag samples failing ENCODE-style QC
  thresholds in the MultiQC summary.
- **Genome-resource helper** to fetch/build BWA indexes and ENCODE blacklists
  for common assemblies.
- **Container per-process granularity** in the Nextflow pipeline (split align /
  peaks / QC into separate processes) for finer resume + resource control.
- **CRAM output** option to reduce storage.

## Explicitly out of scope

- Bundling or redistributing reference genomes / annotations / blacklists.
- Acting as a general-purpose aligner or peak-caller — alignment is delegated to
  BWA and peak calling to MACS2.
