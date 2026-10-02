process RENDER_REPORT {
    tag "$group_meta.id"
    label 'process_low'

    conda "conda-forge::quarto=1.6.41 bioconda::r-pathosurveilr=0.4.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e4/e487168aaa5f7b7a2dfabc1f308869fac1c466ab6bd34acd7a3715d927337c74/data':
        'community.wave.seqera.io/library/r-pathosurveilr_quarto:d4f39be8e8ae4734' }"

    input:
    tuple val(group_meta), file(inputs), path(template, stageAs: 'render_report_template')

    output:
    tuple val(group_meta), path("${prefix}*"), emit: report, optional: true
    path "versions.yml", emit: versions_render_report

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def tmpl = (group_meta.template ?: '').toString().trim()
    def render_target = (group_meta.render_target ?: '').toString().trim()
    def label = tmpl.replaceAll('/+$', '').tokenize('/').last()
    prefix = task.ext.prefix ?: "${group_meta.id}${label ? '_' + label : ''}"
    def target_extension = render_target ? render_target.substring(render_target.lastIndexOf('.')) : ''
    def target_shell = "'" + render_target.replace("'", "'\"'\"'") + "'"
    """

    # Needed to avoid this issue: https://github.com/conda-forge/quarto-feedstock/issues/30
    if [[ -f /opt/conda/etc/conda/activate.d/quarto.sh ]]; then
        source /opt/conda/etc/conda/activate.d/quarto.sh
    fi

    # Tell quarto where to put cache so it does not try to put it where it does nmt have permissions
    export XDG_CACHE_HOME="\$(pwd)/cache"

    # Render a private copy; the staged template may be a symlink to user data.
    cp -r --dereference render_report_template render_report
    rm -rf render_report/.quarto

    quarto render render_report \\
        ${args} \\
        --output-dir "${prefix}" \\
        -P inputs:../${inputs}

    # Locate rendered output
    site_dir="render_report/${prefix}"
    if [[ -d "\$site_dir/_site" ]]; then
        site_dir="\$site_dir/_site"
    fi

    # Publish single target or full directory
    if [[ -n "${render_target}" ]]; then
        target_file="\$site_dir"/${target_shell}
        if [[ -f "\$target_file" ]]; then
            cp -- "\$target_file" "${prefix}${target_extension}"
        fi
    else
        shopt -s nullglob dotglob
        rendered_entries=( "\$site_dir"/* )
        shopt -u nullglob dotglob
        if [[ -d "\$site_dir" && \${#rendered_entries[@]} -gt 0 ]]; then
            mkdir -p "${prefix}"
            cp -R "\$site_dir/." "${prefix}/"
        fi
    fi

    # Clean up
    rm -r render_report

    # Save version of quarto used
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quarto: \$(quarto --version)
        r-PathoSurveilR: \$(Rscript -e "cat(as.character(packageVersion('r-pathosurveilr')))")
    END_VERSIONS
    """
}
