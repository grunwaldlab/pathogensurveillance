process QUAST {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::quast=5.2.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quast:5.2.0--py39pl5321h2add14b_1' :
        'quay.io/biocontainers/quast:5.2.0--py38pl5321h5cf8b27_3' }"

    input:
    tuple val(meta), path(consensus), path(fasta), path(gff)

    output:
    tuple val(meta), path("${prefix}"), emit: results
    tuple val(meta), path('*.tsv')    , emit: tsv
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def features  = gff.size() > 0 ? "--features $gff" : ''
    def reference = fasta.size() > 0 ? "-r $fasta" : ''
    """
    quast.py \\
        --output-dir $prefix \\
        $reference \\
        $features \\
        --threads $task.cpus \\
        $args \\
        ${consensus.join(' ')}

    ln -s ${prefix}/report.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed 's/^.*QUAST v//; s/ .*\$//')
    END_VERSIONS
    """
}
