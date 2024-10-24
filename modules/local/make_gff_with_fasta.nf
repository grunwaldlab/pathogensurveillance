process MAKE_GFF_WITH_FASTA {
    tag "${meta.id}"
    label 'process_single'

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(sequence), path(gff, stageAs: 'input.gff')

    output:
    tuple val(meta), path("${prefix}.gff"), emit: gff

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Copy gff info, removing the last "###" line
    head -n -1 input.gff > ${prefix}.gff

    # Add FASTA section header
    echo "##FASTA" >> ${prefix}.gff
    
    # Add FASTA info, replacing headers with just ID
    sed -E 's/^>([a-zA-Z0-9_.]+) +.*\$/>\\1/g' ${sequence} >> ${prefix}.gff
    """
}
