process BWA_INDEX {
    label 'index'
    tag "${fasta.name}"
    publishDir "${params.outdir}/reference", mode: 'copy'

    input:
    path fasta

    output:
    path "bwa_index", emit: index

    script:
    """
    mkdir -p bwa_index
    bwa index -p bwa_index/${fasta.baseName} ${fasta}
    """

    stub:
    """
    mkdir -p bwa_index
    for ext in amb ann bwt pac sa; do touch bwa_index/${fasta.baseName}.\$ext; done
    """
}
