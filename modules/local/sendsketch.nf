process BBMAP_SENDSKETCH {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::bbmap=39.01"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bbmap:39.01--h5c4e2a8_0':
        'quay.io/biocontainers/bbmap:39.01--h5c4e2a8_0' }"

    input:
    tuple val(meta), path(file)

    output:
    tuple val(meta), path('*.txt')  , emit: hits
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def file_used = file.size() > 1 ? file[0] : file
    """
    sendsketch.sh \\
        in=${file_used} \\
        out=${prefix}.txt \\
        $args \\
        -Xmx${task.memory.toGiga()}g

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh | grep -v "Duplicate cpuset")
    END_VERSIONS
    """
}
