#!/usr/bin/env nextflow
/*
 * ultimaC4walker — Nextflow pipeline
 * FASTQ -> (bwa index) -> align + filter + MACS2 peaks + bigWig + QC -> MultiQC
 *
 * Each sample is processed by the same `c4walker` tool that powers the
 * standalone and container paths, so all three run modes execute identical
 * commands — Nextflow just adds per-sample parallelism, resume and reporting.
 *
 * Usage:
 *   nextflow run nextflow/main.nf \
 *     --samplesheet samples.csv \
 *     --fasta genome.fa \
 *     --outdir results \
 *     -profile docker
 *
 * Samplesheet (CSV) columns:
 *   sample,assay,mark,fastq_1,fastq_2
 * where assay is one of: chipseq | cutrun | cuttag | atac
 * and fastq_2 is empty for single-end data.
 */

nextflow.enable.dsl = 2

include { BWA_INDEX } from './modules/bwa_index.nf'
include { C4WALKER  } from './modules/c4walker_sample.nf'
include { MULTIQC   } from './modules/multiqc.nf'

workflow {

    if (!params.samplesheet) { error "Please provide --samplesheet" }
    if (!params.fasta)       { error "Please provide --fasta" }

    fasta     = file(params.fasta, checkIfExists: true)
    blacklist = params.blacklist ? file(params.blacklist, checkIfExists: true)
                                 : file("${projectDir}/assets/NO_BLACKLIST")

    reads = Channel
        .fromPath(params.samplesheet, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def meta = [ id: row.sample, assay: row.assay.toUpperCase(), mark: row.mark ?: 'NA' ]
            def r1 = file(row.fastq_1, checkIfExists: true)
            def files = (row.fastq_2 && row.fastq_2.trim())
                        ? [ r1, file(row.fastq_2, checkIfExists: true) ]
                        : [ r1 ]
            tuple(meta, files)
        }

    // Build the BWA index once, reuse for every sample (unless one is given).
    if (params.bwa_index) {
        index_ch = Channel.fromPath(params.bwa_index, checkIfExists: true)
    } else {
        index_ch = BWA_INDEX(fasta).index
    }

    C4WALKER(reads, index_ch.collect(), blacklist)

    // Aggregate every per-sample QC directory into one MultiQC report.
    MULTIQC(C4WALKER.out.qc.mix(C4WALKER.out.peaks).collect())
}

workflow.onComplete {
    log.info ( workflow.success
        ? "\n[ultimaC4walker] Done. Results in: ${params.outdir}\n"
        : "\n[ultimaC4walker] Pipeline failed. See .nextflow.log\n" )
}
