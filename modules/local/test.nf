
process TEST {
    tag "$meta.id"
    label 'process_single'

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), val(taxon)

    output:
    path "output.txt"           , emit: output

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    echo $taxon > output.txt
    """
}
