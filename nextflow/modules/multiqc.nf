process MULTIQC {
    label 'process_low'
    tag "multiqc"
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path '*'

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data",        emit: data

    script:
    """
    multiqc . -n multiqc_report -f
    """

    stub:
    """
    mkdir -p multiqc_data
    touch multiqc_report.html
    """
}
