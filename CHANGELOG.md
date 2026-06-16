# Changelog

All notable changes to ultimaC4walker are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres
to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] — 2026-06-16

First public release — a ground-up refactor of the `cccTeqy` prototype into a
modular, testable, multi-runtime workflow.

### Added

- **Four-assay engine** (`bin/c4walker`): ChIP-seq, CUT&RUN, CUT&Tag and
  **ATAC-seq** (new), single- or paired-end, each with the correct MACS2
  strategy — input/IgG controls, Tn5 shift for CUT&Tag (`--shift -75 --extsize
  150`) and ATAC (`--shift -100 --extsize 200`, never a control), and automatic
  `--broad` mode for repressive marks (H3K27me3/H3K9me3/H3K36me3/H4K20me).
- **Modular library** (`lib/`): `align`, `filter`, `peaks`, `signal`, `qc`,
  `hpc` and shared `common` helpers — replacing the single monolithic script.
- **Full pipeline**: FastQC → BWA-MEM → coordinate sort/index → chromosome /
  mitochondrial / MAPQ / ENCODE-blacklist filtering → `samtools markdup`
  deduplication → MACS2 peaks → FRiP → deepTools bigWig → fragment-size,
  preseq library-complexity and phantompeakqualtools (NSC/RSC) QC → MultiQC.
- **Three run modes, one code path**: standalone Bash, Docker / Apptainer
  images bundling the whole toolchain, and a Nextflow pipeline that wraps the
  same engine — so all three execute byte-identical commands.
- **HPC support**: `local`, `slurm` and `pbs` run modes; HPC modes emit one
  job script per sample and submit with `sbatch` / `qsub`.
- **Tool-free `--dry-run`**: prints every command without executing, enabling a
  pure-Bash test suite (`tests/test_c4walker.sh`, 19 assertions) that verifies
  the orchestration on a bare runner.
- **Safe config layer**: flat YAML loaded via `printf -v` (no `eval`), with
  per-key defaults and CLI override; `check` subcommand validates config +
  sample sheet up front.
- **Reproducible deployment**: single-image `Dockerfile` (engine + bioconda
  toolchain), Apptainer definition, `environment.yml`, and a `Makefile`.
- **Runnable example**: a synthetic genome with enriched CUT&Tag and ATAC reads
  (`example/`), auto-falling back to dry-run when tools are absent.
- **CI**: shellcheck + dry-run suite + Nextflow `-stub`; container and Apptainer
  build/publish workflows (Docker Hub + GHCR).
- **Documentation**: README, USAGE, ROADMAP, CONTRIBUTING, SECURITY and a
  published docs site.

### Changed (from `cccTeqy`)

- Monolithic `run.sh` → modular `bin/c4walker` + `lib/*.sh`.
- Duplicate handling moved to a correct name-sort → fixmate → coord-sort →
  `markdup` chain.
- Bash-3.2 portability throughout (indirect expansion instead of associative
  arrays), so the tool runs unchanged on stock macOS bash.

### Heritage

ultimaC4walker began as the `cccTeqy` ChIP-seq/CUT&RUN/CUT&Tag prototype and was
consolidated, hardened, extended with ATAC-seq, made testable, and packaged for
three runtimes for this release.
