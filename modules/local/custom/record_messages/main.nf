process RECORD_MESSAGES {
    tag "All"
    label 'process_single'

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    val messages // list of [meta, group_meta, ref_meta, workflow, level, message]

    output:
    path "messages.tsv", emit: tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    def text = messages
        .findAll { it != [] } // Remove placeholder item added so that this module is run even if there are no messages
        .collect { [it[0] == null ? "NA" : it[0].id, // replace full meta with just IDs
                it[1] == null ? "NA" : it[1].id,
                it[2] == null ? "NA" : it[2].id,
                it[3], it[4], it[5]] }
        .collect {it.join('\t')}
        .join('\n')
    """
    echo -e "sample_id\tgroup_id\tref_id\tworkflow\tlevel\tmessage" >> messages.tsv
    echo "${text}" >> messages.tsv
    """
}
