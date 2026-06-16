process C4WALKER {
    label 'process_high'
    tag "${meta.id}"
    publishDir "${params.outdir}", mode: 'copy'

    input:
    tuple val(meta), path(reads)
    path index_dir
    path blacklist

    output:
    tuple val(meta), path("out/align/${meta.id}/*.filtered*.bam*"), emit: bam
    path "out/peaks/${meta.id}/*",                                  emit: peaks, optional: true
    path "out/bigwig/${meta.id}/*",                                 emit: bigwig, optional: true
    path "out/qc/${meta.id}/**",                                    emit: qc, optional: true

    script:
    // One-row sample sheet + a config that points the tool at the staged
    // reference index and blacklist. The c4walker tool itself does the work,
    // so the standalone and Nextflow paths run byte-identical commands.
    def r1 = reads[0]
    def r2 = reads.size() > 1 ? reads[1] : '-'
    def libtype = reads.size() > 1 ? 'PE' : 'SE'
    def index_prefix = "${index_dir}/${file(params.fasta).baseName}"
    def bl = blacklist.name != 'NO_BLACKLIST' ? "blacklist_bed: ${blacklist}" : ''
    // Build samples.tsv and config.yaml with printf (no heredoc) so the
    // generated bash is indentation-safe inside the Nextflow script block.
    """
    {
      printf 'SAMPLE_ID\\tFASTQ1\\tFASTQ2\\tASSAY\\tMARK\\tCONTROL_ID\\tLIBTYPE\\n'
      printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \\
        '${meta.id}' '${r1}' '${r2}' '${meta.assay}' '${meta.mark}' 'None' '${libtype}'
    } > samples.tsv

    {
      printf 'project_name: %s\\n' '${params.project}'
      printf 'outdir: out\\n'
      printf 'run_mode: local\\n'
      printf 'threads: %s\\n' '${task.cpus}'
      printf 'bwa_index: %s\\n' '${index_prefix}'
      printf 'genome_size: %s\\n' '${params.genome_size}'
      printf 'mito_chr: %s\\n' '${params.mito_chr}'
      printf 'min_mapq: %s\\n' '${params.min_mapq}'
      printf 'remove_duplicates: %s\\n' '${params.remove_duplicates}'
      printf '%s\\n' '${bl}'
    } > config.yaml

    c4walker run -c config.yaml -s samples.tsv
    """

    stub:
    """
    mkdir -p out/align/${meta.id} out/peaks/${meta.id} out/bigwig/${meta.id} out/qc/${meta.id}
    touch out/align/${meta.id}/${meta.id}.filtered.nodup.bam
    touch out/align/${meta.id}/${meta.id}.filtered.nodup.bam.bai
    touch out/peaks/${meta.id}/${meta.id}_peaks.narrowPeak
    touch out/bigwig/${meta.id}/${meta.id}.RPKM.bw
    touch out/qc/${meta.id}/${meta.id}.flagstat.txt
    """
}
