# ultimaC4walker

**Ultimate walker for the four chromatin-profiling assays — ChIP-seq, CUT&RUN, CUT&Tag and ATAC-seq.**

`ultimaC4walker` takes raw **FASTQ to peaks, coverage tracks and a full QC
report** in one command. It is a single, dependency-light Bash engine
(`c4walker`) that runs three ways from the same code path — as a **standalone
tool**, inside **Docker / Apptainer** images that bundle the whole toolchain,
or as an **integrated Nextflow pipeline** — on a laptop or across SLURM / PBS
clusters.

[![CI](https://github.com/ebareke/ultimaC4walker/actions/workflows/ci.yml/badge.svg)](https://github.com/ebareke/ultimaC4walker/actions/workflows/ci.yml)
[![Containers](https://github.com/ebareke/ultimaC4walker/actions/workflows/containers.yml/badge.svg)](https://github.com/ebareke/ultimaC4walker/actions/workflows/containers.yml)
![Bash](https://img.shields.io/badge/bash-3.2%2B-green)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platforms](https://img.shields.io/badge/platform-linux%20%7C%20macOS-lightgrey)
[![Docs](https://img.shields.io/badge/docs-ebareke.github.io-1E6B4F)](https://ebareke.github.io/ultimaC4walker/)

Documentation: **<https://ebareke.github.io/ultimaC4walker/>**

---

## Features

- 🧬 **Four assays, one engine** — ChIP-seq, CUT&RUN, CUT&Tag and ATAC-seq,
  single-end or paired-end, each with the right MACS strategy (input/IgG
  controls, Tn5 shift for CUT&Tag/ATAC, broad mode for repressive marks).
  Peak calling uses **MACS3** (MACS2-compatible; `macs2:` still accepted).
- 🧰 **FASTQ → results** — FastQC → BWA-MEM alignment → chromosome / mito /
  MAPQ / ENCODE-blacklist filtering → duplicate removal → MACS2 peaks →
  bigWig tracks → FRiP, fragment-size, library-complexity and cross-correlation
  QC → **MultiQC**.
- 🖥️ **Local *and* HPC** — `local`, `slurm` and `pbs` run modes from the same
  config; HPC modes emit one job script per sample and submit them.
- 📦 **Three run modes, identical commands** — standalone Bash, Docker /
  Apptainer images, and a Nextflow pipeline that wraps the very same tool.
- 🧪 **Tool-free dry-run** — `--dry-run` prints every command without executing,
  so the orchestration is fully testable (and CI-verified) on a bare runner.
- ⚙️ **Unified YAML config + TSV sample sheet** — no code editing; CLI flags
  override config.
- 🪶 **Dependency-light** — the driver is portable Bash (3.2+); the heavy tools
  live in the container or your conda env.

## Install

### From source (Bash ≥ 3.2 + the bioinformatics tools)

```bash
git clone https://github.com/ebareke/ultimaC4walker.git
cd ultimaC4walker
./bin/c4walker version

# Tools via conda (bwa, samtools, bedtools, macs2, fastqc, deeptools, ...)
mamba env create -f environment.yml && mamba activate c4walker
```

### Container (no installs; bundles the whole toolchain)

```bash
docker build -t ultimac4walker:1.0.0 .
docker run --rm ultimac4walker:1.0.0 help
```

See [containers/README.md](containers/README.md) for Apptainer / Singularity.

## Quick start

### Standalone

```bash
c4walker run -c config/config.yaml -s config/samples.tsv
```

### Dry-run (prints every command, runs nothing)

```bash
c4walker run -c config/config.yaml -s config/samples.tsv --dry-run
```

### Nextflow (FASTQ → peaks, parallel + resumable)

```bash
nextflow run nextflow/main.nf \
    --samplesheet samples.csv --fasta genome.fa \
    --blacklist hg38-blacklist.bed -profile docker
```

### Try the bundled example

```bash
bash example/run_example.sh
```

Generates a tiny synthetic genome with enriched CUT&Tag and ATAC reads and runs
the pipeline end-to-end (auto dry-run if the tools aren't installed). See
[example/README.md](example/README.md).

## How it works

```
FASTQ ─▶ FastQC ─▶ BWA-MEM ─▶ sorted BAM ─▶ filter ─▶ MACS2 ─▶ peaks
                                            │  chrom/mito         │
                                            │  MAPQ               ├─▶ FRiP
                                            │  blacklist          ├─▶ bigWig (deepTools)
                                            │  dedup              ├─▶ fragment size
                                            └─────────────────────┴─▶ preseq · phantompeak
                                                                          │
                                                                          ▼
                                                                       MultiQC
```

The same `c4walker` engine drives all three run modes, so the standalone tool,
the containers and the Nextflow pipeline execute byte-identical commands.

## Sample sheet

Tab-delimited, with a header. `ASSAY ∈ {CHIPSEQ, CUTRUN, CUTTAG, ATAC}`,
`LIBTYPE ∈ {PE, SE}`, `CONTROL_ID` is another sample's id or `None`.

```tsv
SAMPLE_ID	FASTQ1	FASTQ2	ASSAY	MARK	CONTROL_ID	LIBTYPE
H3K27me3_r1	r1_R1.fq.gz	r1_R2.fq.gz	CUTTAG	H3K27me3	None	PE
CTCF_r1	ctcf_R1.fq.gz	-	CHIPSEQ	CTCF	input_r1	SE
ATAC_r1	atac_R1.fq.gz	atac_R2.fq.gz	ATAC	NA	None	PE
```

## Project layout

```
bin/c4walker        the engine (argument parsing + per-sample orchestration)
lib/                sourced modules: align, filter, peaks, signal, qc, hpc
config/             example config.yaml + container config + samples.tsv
environment.yml     conda toolchain (also used by the Dockerfile)
Dockerfile          single-image build (engine + full toolchain)
containers/         Apptainer definition + container docs
nextflow/           FASTQ → peaks pipeline (wraps the same engine) + modules
example/            synthetic end-to-end example (auto dry-run fallback)
tests/              tool-free dry-run test suite
docs/               published documentation site
```

## Documentation

| File | Contents |
|---|---|
| [USAGE.md](USAGE.md) | Full CLI + config reference, recipes, outputs |
| [example/README.md](example/README.md) | Runnable end-to-end example |
| [nextflow/README.md](nextflow/README.md) | FASTQ → peaks pipeline |
| [containers/README.md](containers/README.md) | Docker / Apptainer images |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [ROADMAP.md](ROADMAP.md) | Planned work |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [SECURITY.md](SECURITY.md) | Security model and reporting |
| [CITATION.md](CITATION.md) · [CITATION.cff](CITATION.cff) | How to cite ultimaC4walker |

## Citing

If you use ultimaC4walker in your research, please cite it — see
[CITATION.md](CITATION.md) for software, BibTeX and APA entries plus the
underlying tools to credit. GitHub's **“Cite this repository”** button is
generated from [CITATION.cff](CITATION.cff).

## Authors

- **Eric Bareke** — <eb.bioinfo@pm.me>
- **Ethan M.** — <eb.bioinfo@pm.me>
- **Conrad B.** — <eb.bioinfo@pm.me>

## License

[MIT](LICENSE) © 2026 Eric Bareke, Ethan M., and Conrad B.
