process MAIN_REPORT {
    tag "$group_meta.id"
    label 'process_low'

    conda "conda-forge::quarto=1.6.41 bioconda::r-pathosurveilr=0.4.8"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e4/e487168aaa5f7b7a2dfabc1f308869fac1c466ab6bd34acd7a3715d927337c74/data':
        'community.wave.seqera.io/library/r-pathosurveilr_quarto:d4f39be8e8ae4734' }"

    input:
    tuple val(group_meta), file(inputs), path(template, stageAs: 'main_report_template')

    output:
    // The report is published as a directory: the whole rendered site, or, when report_data sets
    // a render_target, a directory holding just that page renamed after the template directory.
    tuple val(group_meta), path("${prefix}"), emit: html
    tuple val(group_meta), path("${prefix}.pdf") , emit: pdf, optional: true
    path "versions.yml"               , emit: versions_main_report

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def tmpl = (group_meta.template ?: '').toString().trim()
    // Optional single-file mode: publish only the rendered page for this .qmd, renamed after the
    // template directory, instead of the whole site. The target is a base name; a path is
    // rejected so a row cannot pull in a .qmd from outside the template.
    def render_target = (group_meta.render_target ?: '').toString().trim()
    if (render_target.contains('/')) {
        throw new IllegalArgumentException("report_data render_target '${render_target}' must be the base name of a .qmd in the template directory, not a path")
    }

    // A template may be given as an absolute path; only its final segment names the report
    // Trailing slashes are stripped first so a typo still names the report after the directory
    def label = tmpl.replaceAll('/+$', '')
    label = label.contains('/') ? label.substring(label.lastIndexOf('/') + 1) : label
    if (label == '.' || label == '..') {
        throw new IllegalArgumentException("report_data template '${tmpl}' does not name a usable report directory")
    }
    prefix = task.ext.prefix ?: "${group_meta.id}${label ? '_' + label : ''}"
    """

    # Needed to avoid this issue: https://github.com/conda-forge/quarto-feedstock/issues/30
    if [[ -f /opt/conda/etc/conda/activate.d/quarto.sh ]]; then
        source /opt/conda/etc/conda/activate.d/quarto.sh
    fi

    # Tell quarto where to put cache so it does not try to put it where it does nmt have permissions
    export XDG_CACHE_HOME="\$(pwd)/cache"

    # Template is always a directory containing .qmd (dir-only per report_data spec).
    # Never modify main_report_template itself: it is staged as a symlink into the user's template directory
    cp -r --dereference main_report_template main_report

    # .quarto is a committed developer-machine project cache (xref/idx/freeze); the shipped
    # template carries one, and a stale freeze would corrupt the render.
    rm -rf main_report/.quarto

    # quarto resolves --output-dir relative to the project dir, so the site lands in
    # main_report/${prefix}/. A render_target renders only that one .qmd; a full site is still
    # allowed, it is the user's responsibility to make the target page self-contained.
    if [[ -n "${render_target}" ]]; then
        if [[ ! -f "main_report/${render_target}.qmd" ]]; then
            echo "ERROR: render_target '${render_target}.qmd' is not present in the template directory" >&2
            exit 1
        fi
        render_input="main_report/${render_target}.qmd"
    else
        render_input="main_report"
    fi
    quarto render \${render_input} \\
        ${args} \\
        --output-dir "${prefix}" \\
        -P inputs:../${inputs}

    # Locate the rendered report site
    for tool in cp rm; do
        command -v \$tool >/dev/null 2>&1 || { echo "ERROR: required tool '\$tool' not found in the task image" >&2; exit 1; }
    done
    site_dir="main_report/${prefix}"
    if [[ ! -d \$site_dir ]]; then
        echo "ERROR: expected quarto output directory \$site_dir was not created" >&2
        exit 1
    fi

    # The _site descent is a guard for a version that nests a website site one level down,
    # which would otherwise bury the report under a redundant _site/ level.
    if [[ -d "\$site_dir/_site" ]]; then
        site_dir="\$site_dir/_site"
    fi

    # Fail loudly if nothing rendered, rather than publishing an empty directory
    shopt -s nullglob
    html_files=( "\$site_dir"/*.html "\$site_dir"/*/*.html "\$site_dir"/*/*/*.html )
    shopt -u nullglob
    if [[ \${#html_files[@]} -eq 0 ]]; then
        echo "ERROR: quarto produced no HTML in \$site_dir" >&2
        exit 1
    fi

    rm -rf "${prefix}"
    mkdir -p "${prefix}"

    if [[ -n "${render_target}" ]]; then
        # Single-file mode: the rendered page is the whole published report, renamed after the
        # template directory. Sources are deliberately not published, since a self-contained page
        # does not need them and the point of the option is a one-file output.
        target_html="\${site_dir}/${render_target}.html"
        if [[ ! -f "\$target_html" ]]; then
            echo "ERROR: quarto did not produce \$target_html" >&2
            exit 1
        fi
        cp "\$target_html" "${prefix}/${prefix}.html"
    else
        # Publish the template sources alongside the render, so relative references a stylesheet
        # or custom filter relies on still resolve and the .qmd files ship with the report.
        shopt -s nullglob dotglob
        for src in main_report_template/*; do
            # .quarto is the only exclusion. Everything else is published.
            case "\$(basename "\$src")" in
                .quarto) continue ;;
            esac
            # --dereference so a symlink inside the template lands as a real file
            cp -r --dereference "\$src" "${prefix}/"
        done
        shopt -u nullglob dotglob

        # Rendered output last, so the product always wins a name clash with a source file.
        cp -R "\$site_dir/." "${prefix}/"
    fi

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
