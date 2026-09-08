process MAIN_REPORT {
    tag "$group_meta.id"
    label 'process_low'

    conda "conda-forge::quarto=1.6.41 bioconda::r-pathosurveilr=0.4.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e4/e487168aaa5f7b7a2dfabc1f308869fac1c466ab6bd34acd7a3715d927337c74/data':
        'community.wave.seqera.io/library/r-pathosurveilr_quarto:d4f39be8e8ae4734' }"

    input:
    tuple val(group_meta), file(inputs)
    path template, stageAs: 'main_report_template'

    output:
    tuple val(group_meta), path("${prefix}_pathsurveil_report.html"), emit: html
    tuple val(group_meta), path("${prefix}_pathsurveil_report.pdf") , emit: pdf, optional: true
    path "versions.yml"                                             , emit: versions_main_report

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${group_meta.id}"
    """
    # Needed to avoid this issue: https://github.com/conda-forge/quarto-feedstock/issues/30
    if [[ -f /opt/conda/etc/conda/activate.d/quarto.sh ]]; then
        source /opt/conda/etc/conda/activate.d/quarto.sh
    fi
    # Tell quarto where to put cache so it does not try to put it where it does nmt have permissions
    export XDG_CACHE_HOME="\$(pwd)/cache"

    # Copy source of report here cause quarto seems to want to make its output in the source
    cp -r --dereference main_report_template main_report

    # Render the report
    quarto render main_report \\
        ${args} \\
        --output-dir ${prefix}_report \\
        -P inputs:../${inputs}

    # Rename outputs
    mv main_report/${prefix}_report/index.html ${prefix}_pathsurveil_report.html

    # Clean up
    rm -r main_report

    # Save version of quarto used
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quarto: \$(quarto --version)
        r-PathoSurveilR: \$(Rscript -e "cat(as.character(packageVersion('dplyr')))")
    END_VERSIONS
    """
}
