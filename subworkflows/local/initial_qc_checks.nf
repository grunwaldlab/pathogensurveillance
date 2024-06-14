include { FASTQC        } from '../../modules/nf-core/fastqc/main'
include { NANOPLOT      } from '../../modules/nf-core/nanoplot/main'

workflow INITIAL_QC_CHECKS {

    take:
    sample_data

    main:
    versions = Channel.empty()
    messages = Channel.empty()

    // Run FastQC
    shortreads = sample_data
        .filter { it.sequence_type == "illumina" }
        .map { [[id: it.sample_id], it.paths] }
        .unique()
    FASTQC ( shortreads )
    versions = versions.mix(FASTQC.out.versions.toSortedList().map{it[0]})

    //// Run Nanoplot
    //nanopore_reads = sample_data
    //    .filter { it.sequence_type == "nanopore" }
    //    .map { [[id: it.sample_id], it.paths] }
    //    .unique()
    //NANOPLOT ( nanopore_reads )
    //versions = versions.mix(NANOPLOT.out.versions.toSortedList().map{it[0]})

    emit:
    versions      = versions                                // versions
    messages      = messages                                   // meta, group_meta, ref_meta, workflow, level, message
}
