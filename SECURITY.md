# Security

## Model

ultimaC4walker is an offline command-line workflow. It reads local sequencing
files (FASTQ, BAM), a genome index and optional BED/reference resources, writes
local results, and makes **no network calls** during analysis. There is no
server, no account, and no telemetry. (The container build and the optional
MultiQC report assets are the only steps that touch a network, at build time.)

What this leaves, and how it is handled:

| Surface | Handling |
|---|---|
| Config parsing | The YAML reader accepts only flat `key: value` scalars and assigns them with `printf -v` — **never `eval`** — so a hostile config value cannot execute code. |
| Sample sheet | Validated up front (`check`): ASSAY, LIBTYPE and FASTQ presence are checked before any command runs; bad rows fail fast. |
| Command execution | All steps run under `set -euo pipefail`; a failing tool aborts the run with a non-zero exit rather than continuing on corrupt intermediates. |
| Untrusted inputs | FASTQ/BAM are passed to standard, widely-audited tools (bwa, samtools, MACS2); the driver adds no custom binary parsing. |
| Containers | The image pins a bioconda toolchain; the driver itself is plain Bash with no compiled attack surface. |
| `--dry-run` | Prints commands without executing — use it to audit exactly what will run before a real invocation. |

Known, documented limitations:

- The tool trusts that input FASTQ/BAM correspond to the provided BWA index and
  genome size; it validates structure and sheet consistency, not biological
  provenance.
- File paths in the config and sample sheet are used as given; run the tool with
  inputs you control, as you would any shell-based pipeline.

## Reporting a vulnerability

Email **eb.bioinfo@pm.me** with a description and reproduction steps.
Please do not open public issues for exploitable problems before a fix is
available. You can expect an acknowledgement within a few days; fixes are
best-effort but security reports get priority.
