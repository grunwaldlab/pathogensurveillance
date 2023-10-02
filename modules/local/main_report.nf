process MAIN_REPORT {
    tag "$group_meta.id"
    label 'process_low'

    conda "conda-forge::quarto=1.3.450" // TODO: it just uses the local computers R packages for now
    container null

    input:
    tuple val(group_meta), val(ref_metas), file(snp_phylos), file(snp_aligns), file(vcfs), file(quast_dirs), file(ani_matrix), file(core_phylo), file(sendsketchs)
    path samp_data
    path ref_data
    path multiqc_data
    path multiqc_plots
    path multiqc_report
    path versions

    output:
    tuple val(group_meta), path("main_report/${prefix}_report"), emit: html
    path "versions.yml"                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${group_meta.id}"
    def ref_ids = ref_metas.collect{ it.id }.join(';')
    """
    # Copy source of report here cause quarto seems to want to make its output in the source
    cp -r ${projectDir}/assets/main_report ./
    
    # Make directory for inputs so that a single path can be passed as parameters
    mkdir inputs
    
    # Put multiqc's output into a single folder for organization
    mkdir inputs/multiqc
    cp -r ${multiqc_data} inputs/multiqc/
    cp -r ${multiqc_plots} inputs/multiqc/                                              
    cp -r ${multiqc_report} inputs/multiqc/
    
    # Put quast's output into a single folder for organization
    mkdir inputs/quast
    cp -r ${quast_dirs} inputs/quast/
    
    # Put sendsketch's output into a single folder for organization
    mkdir inputs/sendsketch
    cp -r ${sendsketchs} inputs/sendsketch/

    # Put variant data into a single folder for organization
    mkdir inputs/variant_data
    cp -r ${snp_phylos} inputs/variant_data/
    cp -r ${vcfs} inputs/variant_data/
    cp -r ${snp_aligns} inputs/variant_data/
    
    # Save report group name to file
    echo ${group_meta.id} > inputs/group_id.txt
    
    # Save reference IDs to file
    echo ${ref_ids} > inputs/ref_ids.txt
    
    # Move single-value paths to input directory
    mkdir other_inputs
    mv ${samp_data} inputs/samp_data.csv
    mv ${ref_data} inputs/ref_data.tsv
    mv ${ani_matrix} inputs/ani_matrix.csv
    mv ${core_phylo} inputs/core_phylo.treefile
    mv ${versions} inputs/versions.yml
    
    # Render the report
    quarto render main_report \\
        --output-dir ${prefix}_report \\
        -P inputs:..

    # Save version of quarto used
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quarto: \$(quarto --version)
    END_VERSIONS
    """
}
