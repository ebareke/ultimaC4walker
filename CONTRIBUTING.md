# Contributing

Issues and pull requests are welcome.

## Getting started

```bash
git clone https://github.com/ebareke/ultimaC4walker.git
cd ultimaC4walker
./bin/c4walker version
bash tests/test_c4walker.sh        # tool-free dry-run suite (19 assertions)
bash example/run_example.sh        # end-to-end (auto dry-run if tools absent)
```

For a real run, create the toolchain with `mamba env create -f environment.yml`
or use the container (`docker build -t ultimac4walker:1.0.0 .`).

## Ground rules

- **Correctness first.** Genomic logic must be backed by a test. The `--dry-run`
  mode makes the orchestration assertable without installing aligners — new
  behaviour comes with an assertion in `tests/test_c4walker.sh`.
- **One engine, three runtimes.** The standalone tool, the containers and the
  Nextflow pipeline must keep running the *same* `c4walker` commands. Don't fork
  the logic into the Nextflow modules.
- **No silent fallbacks.** A step either runs the real tool or returns a typed
  error; optional tools are explicitly logged and skipped, never faked.
- **Portable Bash.** The driver targets bash 3.2+ (stock macOS). Avoid
  associative arrays and other bash-4-only features; prefer `printf -v` and
  indirect expansion.

## Where contributions help most

- **New assays / peak-calling strategies** in `lib/peaks.sh` — each should come
  with dry-run assertions covering its MACS2 flags and control handling.
- **QC modules** in `lib/qc.sh` — keep them optional-tool-tolerant.
- **Nextflow ergonomics** in `nextflow/` — keep processes container-pinned and
  provide a `stub:` block so `-stub` CI stays green.
- **Real-data robustness** — odd chromosome naming, CRAM inputs, unusual
  blacklists make great regression fixtures.

## Pull-request checklist

- [ ] `bash tests/test_c4walker.sh` passes; new behaviour has assertions.
- [ ] `shellcheck -x bin/c4walker lib/*.sh` is clean (or `make lint`).
- [ ] `bash example/run_example.sh` still completes.
- [ ] User-facing changes are reflected in `USAGE.md` and `CHANGELOG.md`.

## Commit style

Short imperative subject lines ("Add IDR replicate handling", "Fix ATAC bigWig
extension"). Reference issues where relevant.

## Maintainers

- Eric B. — <eb.bioinfo@pm.me>
- Ethan M. — <eb.bioinfo@pm.me>
- Conrad B. — <eb.bioinfo@pm.me>
