# ultimaC4walker Nextflow pipeline

A complete **FASTQ → filtered BAM → MACS2 peaks → bigWig → QC → MultiQC**
workflow for **ChIP-seq, CUT&RUN, CUT&Tag and ATAC-seq**.

Every sample is processed by the same `c4walker` engine that powers the
standalone and container paths, so all three run modes execute byte-identical
commands. Nextflow adds per-sample parallelism, `-resume`, and execution
reports. The only host requirements are **Nextflow ≥ 23.04** and a container
engine (Docker / Singularity / Apptainer).

## Samplesheet

CSV with a header row:

```csv
sample,assay,mark,fastq_1,fastq_2
H3K27me3_r1,cuttag,H3K27me3,reads/H3K27me3_r1_R1.fq.gz,reads/H3K27me3_r1_R2.fq.gz
CTCF_r1,chipseq,CTCF,reads/CTCF_r1.fq.gz,
ATAC_r1,atac,NA,reads/ATAC_r1_R1.fq.gz,reads/ATAC_r1_R2.fq.gz
```

* `assay` ∈ `chipseq` | `cutrun` | `cuttag` | `atac`.
* `fastq_2` empty ⇒ single-end.

## Run

```bash
nextflow run nextflow/main.nf \
    --samplesheet samples.csv \
    --fasta genome.fa \
    --blacklist hg38-blacklist.bed \
    --genome_size hs \
    --outdir results \
    -profile docker
```

Provide `--bwa_index <prefix-glob>` to reuse a pre-built index and skip the
`BWA_INDEX` step. Swap `-profile docker` for `singularity` / `apptainer` on HPC.

## Built-in test

The bundled synthetic dataset is wired into the `test` profile. Generate it,
then run a stub (no tools needed) or a real pass (needs the container):

```bash
python3 example/scripts/make_synthetic.py     # reference + reads + samplesheet

# Topology check, no aligner required:
nextflow run nextflow/main.nf -profile test -stub

# Real end-to-end inside the container:
nextflow run nextflow/main.nf -profile test,docker
```

## Parameters

| Parameter            | Default                                    | Description                              |
|----------------------|--------------------------------------------|------------------------------------------|
| `--samplesheet`      | —                                          | CSV described above (required)           |
| `--fasta`            | —                                          | Genome FASTA (required)                  |
| `--bwa_index`        | `null`                                     | Pre-built BWA index prefix (optional)    |
| `--blacklist`        | `null`                                     | ENCODE blacklist BED (optional)          |
| `--genome_size`      | `hs`                                       | MACS2 effective genome size              |
| `--mito_chr`         | `chrM`                                     | Mitochondrial contig to drop             |
| `--min_mapq`         | `30`                                       | Minimum mapping quality                  |
| `--remove_duplicates`| `1`                                        | Remove duplicates (1) or keep (0)        |
| `--outdir`           | `results`                                  | Output directory                         |
| `--container`        | `ghcr.io/ebareke/ultimac4walker:1.0.0`     | Container image used by every process    |

## Outputs

```
results/
├── align/<sample>/       filtered, deduplicated, indexed BAMs
├── peaks/<sample>/        MACS2 narrow/broad peaks + bedGraph
├── bigwig/<sample>/       normalised coverage tracks
├── qc/<sample>/           FastQC, samtools, FRiP, fragment size, preseq
├── multiqc/               aggregated MultiQC report
└── pipeline_info/         timeline, report, trace
```
