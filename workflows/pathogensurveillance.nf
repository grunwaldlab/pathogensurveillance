/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPathogensurveillance.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.sample_data,
    params.reference_data,
    params.multiqc_config
]
for (param in checkPathParamList) {
    if (param) { file(param, checkIfExists: true) }
}

// Check mandatory parameters
if (params.sample_data) {
    sample_data_csv = file(params.sample_data)
} else {
    exit 1, 'Sample metadata CSV not specified.'
}
if (params.reference_data) {
    reference_data_csv = file(params.reference_data)
} else {
    reference_data_csv = []
}
if (!params.bakta_db && !params.download_bakta_db ) {
    exit 1, "No bakta database specified. Use either '--bakta_db' to point to a local bakta database or use '--download_bakta_db true' to download the Bakta database."
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PREPARE_INPUT            } from '../subworkflows/local/prepare_input'
include { COARSE_SAMPLE_TAXONOMY   } from '../subworkflows/local/coarse_sample_taxonomy'
include { CORE_GENOME_PHYLOGENY    } from '../subworkflows/local/core_genome_phylogeny'
include { VARIANT_ANALYSIS         } from '../subworkflows/local/variant_analysis'
include { DOWNLOAD_REFERENCES      } from '../subworkflows/local/download_references'
include { ASSIGN_REFERENCES        } from '../subworkflows/local/assign_references'
include { GENOME_ASSEMBLY          } from '../subworkflows/local/genome_assembly'
include { BUSCO_PHYLOGENY          } from '../subworkflows/local/busco_phylogeny'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

include { SRATOOLS_FASTERQDUMP        } from '../modules/local/fasterqdump'
include { MAIN_REPORT                 } from '../modules/local/main_report'
include { RECORD_MESSAGES             } from '../modules/local/record_messages'
include { DOWNLOAD_ASSEMBLIES         } from '../modules/local/download_assemblies'
include { PREPARE_REPORT_INPUT        } from '../modules/local/prepare_report_input'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow PATHOGENSURVEILLANCE {

    // Initalize channel to accumulate information about software versions used
    version_data = Channel.empty()
    // Initalize messages channel with an empty list
    //     Note that at least one value is needed so that modlues that require this are run
    messages = Channel.fromList([[]])

    // Read in samplesheet, validate and stage input files
    PREPARE_INPUT ( sample_data_csv, reference_data_csv )
    version_data = version_data.mix(PREPARE_INPUT.out.versions)

    // Run FastQC
    shortreads = PREPARE_INPUT.out.sample_data
        .filter { sample_meta, read_paths, report_meta, ref_metas ->
            sample_meta.reads_type == "illumina"
        }
        .map { sample_meta, read_paths, report_meta, ref_metas ->
            [sample_data, read_paths]
        }
        .unique()
    FASTQC ( shortreads )
    version_data = version_data.mix(FASTQC.out.versions.toSortedList().map{it[0]})

    // Make initial taxonomic classification to decide how to treat sample
    reads = PREPARE_INPUT.out.sample_data
        .map { sample_meta, read_paths, report_meta, ref_metas ->
            [sample_data, read_paths]
        }
        .unique()
    COARSE_SAMPLE_TAXONOMY ( reads )
    version_data = version_data.mix(COARSE_SAMPLE_TAXONOMY.out.versions)

    // Search for and download reference assemblies for all samples
    DOWNLOAD_REFERENCES (
        COARSE_SAMPLE_TAXONOMY.out.species,
        COARSE_SAMPLE_TAXONOMY.out.genera,
        COARSE_SAMPLE_TAXONOMY.out.families,
        PREPARE_INPUT.out.sample_data
    )
    version_data = version_data.mix(DOWNLOAD_REFERENCES.out.versions)

    //// Assign closest reference for samples without a user-assigned reference
    //ASSIGN_REFERENCES (
    //    ch_input_parsed,
    //    DOWNLOAD_REFERENCES.out.assem_samp_combos,
    //    DOWNLOAD_REFERENCES.out.sequence,
    //    DOWNLOAD_REFERENCES.out.signatures,
    //    COARSE_SAMPLE_TAXONOMY.out.depth
    //)
    //version_data = version_data.mix(ASSIGN_REFERENCES.out.versions)
    //messages = messages.mix(ASSIGN_REFERENCES.out.messages)

    //// Call variants and create SNP-tree and minimum spanning nextwork
    //VARIANT_ANALYSIS (
    //    ASSIGN_REFERENCES.out.sample_data, // meta, [reads], ref_meta, reference, group_meta
    //    PREPARE_INPUT.out.csv
    //)
    //version_data = version_data.mix(VARIANT_ANALYSIS.out.versions)
    //messages = messages.mix(VARIANT_ANALYSIS.out.messages)

    //// Assemble and annotate bacterial genomes
    //GENOME_ASSEMBLY (
    //    ASSIGN_REFERENCES.out.sample_data
    //        .combine(COARSE_SAMPLE_TAXONOMY.out.kingdom, by: 0)
    //        .combine(COARSE_SAMPLE_TAXONOMY.out.depth, by: 0)
    //)
    //version_data = version_data.mix(GENOME_ASSEMBLY.out.versions)

    //// Create core gene phylogeny for bacterial samples
    //ref_gffs = ASSIGN_REFERENCES.out.context_refs
    //    .transpose() // group_meta, ref_meta
    //    .map { group_meta, ref_meta -> [ref_meta, group_meta] }
    //    .combine(DOWNLOAD_REFERENCES.out.gff, by: 0) // ref_meta, group_meta, gff
    //    .map { ref_meta, group_meta, gff -> [group_meta, gff] }
    //    .groupTuple() // group_meta, [gff]
    //    .combine(ASSIGN_REFERENCES.out.sample_data.map{ meta, fastq, ref_meta, ref, group_meta -> [group_meta, meta] }, by: 0)
    //    .map { group_meta, gff_list, meta -> [meta, gff_list] }
    //gff_and_group = ASSIGN_REFERENCES.out.sample_data  // meta, [fastq], ref_meta, reference, group_meta
    //    .combine(GENOME_ASSEMBLY.out.gff, by: 0) // meta, [fastq], ref_meta, reference, group_meta, gff
    //    .combine(ref_gffs, by: 0) // meta, [fastq], ref_meta, reference, group_meta, gff, [ref_gff]
    //    .combine(COARSE_SAMPLE_TAXONOMY.out.depth, by:0) // meta, [fastq], ref_meta, reference, group_meta, gff, [ref_gff], depth
    //    .map { [it[0], it[5], it[4], it[6], it[7]] } // meta, gff, group_meta, [ref_gff], depth
    //CORE_GENOME_PHYLOGENY (
    //    gff_and_group,
    //    PREPARE_INPUT.out.csv
    //)
    //version_data = version_data.mix(CORE_GENOME_PHYLOGENY.out.versions)
    //messages  = messages.mix(CORE_GENOME_PHYLOGENY.out.messages)

    //// Read2tree BUSCO phylogeny for eukaryotes
    //ref_metas = ASSIGN_REFERENCES.out.context_refs // group_meta, [ref_meta]
    //    .combine(ASSIGN_REFERENCES.out.sample_data.map{ meta, fastq, ref_meta, ref, group_meta -> [group_meta, meta] }, by: 0)
    //    .map { group_meta, ref_meta_list, meta -> [meta, ref_meta_list] }
    //busco_input = ASSIGN_REFERENCES.out.sample_data  // val(meta), [file(fastq)], val(ref_meta), file(reference), val(group_meta)
    //    .combine(ref_metas, by: 0) // val(meta), [file(fastq)], val(ref_meta), file(reference), val(group_meta), [val(ref_meta)]
    //    .combine(COARSE_SAMPLE_TAXONOMY.out.kingdom, by: 0) // val(meta), [file(fastq)], val(ref_meta), file(reference), val(group_meta), [val(ref_meta)], val(kingdom)
    //    .combine(COARSE_SAMPLE_TAXONOMY.out.depth, by:0) // val(meta), [file(fastq)], val(ref_meta), file(reference), val(group_meta), [val(ref_meta)], val(kingdom), val(depth)
    //    .map { it[0..1] + it[4..7] } // val(meta), [file(fastq)], val(group_meta), [val(ref_meta)], val(kingdom), val(depth)
    //BUSCO_PHYLOGENY (
    //    busco_input,
    //    DOWNLOAD_REFERENCES.out.sequence
    //)

    //// Save version info
    //CUSTOM_DUMPSOFTWAREVERSIONS (
    //    version_data.unique().collectFile(name: 'collated_versions.yml')
    //)


    //// MultiQC
    //workflow_summary    = WorkflowPathogensurveillance.paramsSummaryMultiqc(workflow, summary_params)
    //ch_workflow_summary = Channel.value(workflow_summary)

    //methods_description    = WorkflowPathogensurveillance.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    //ch_methods_description = Channel.value(methods_description)

    //ch_multiqc_files = Channel.empty()
    //ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    //ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    //MULTIQC (
    //    ch_multiqc_files.collect(),
    //    ch_multiqc_config.collect().ifEmpty([]),
    //    ch_multiqc_custom_config.collect().ifEmpty([]),
    //    ch_multiqc_logo.collect().ifEmpty([])
    //)
    //multiqc_report = MULTIQC.out.report.toList()
    //version_data    = version_data.mix(MULTIQC.out.versions)

    //// Save error/waring/message info
    //RECORD_MESSAGES (
    //    messages.collect(flat:false)
    //)

    //// Create main summary report
    //report_samp_data = ASSIGN_REFERENCES.out.sample_data // meta, [reads], ref_meta, reference, group_meta
    //    .combine(COARSE_SAMPLE_TAXONOMY.out.hits, by:0) // meta, [reads], ref_meta, reference, group_meta, sendsketch
    //    .combine(DOWNLOAD_REFERENCES.out.stats, by:0) // meta, [reads], ref_meta, reference, group_meta, sendsketch, ref_stats
    //    .map { [it[2]] + it[0..1] + it[3..6] } // ref_meta, meta, [reads], reference, group_meta, sendsketch, ref_stats
    //    .join(GENOME_ASSEMBLY.out.quast, remainder: true, by:0) // ref_meta, meta, [reads], reference, group_meta, sendsketch, ref_stats, quast
    //    .map { [it[4]] + it[0..3] + it[5..7]} // group_meta, ref_meta, meta, [reads], reference, sendsketch, ref_stats, quast
    //    .groupTuple() // group_meta, [ref_meta], [meta], [reads], [reference], [sendsketch], [ref_stats], [quast]
    //report_variant_data = VARIANT_ANALYSIS.out.results // group_meta, ref_meta, vcf, align, tree
    //    .groupTuple() // group_meta, [ref_meta], [vcf], [align], [tree]
    //report_group_data = ASSIGN_REFERENCES.out.ani_matrix // group_meta, ani_matrix
    //    .join(CORE_GENOME_PHYLOGENY.out.phylogeny, remainder:true) // group_meta, ani_matrix, [core_phylo]
    //    .join(CORE_GENOME_PHYLOGENY.out.pocp, remainder:true) // group_meta, ani_matrix, [core_phylo], popc
    //    .join(ASSIGN_REFERENCES.out.mapping_ref, remainder:true) // group_meta, ani_matrix, [core_phylo], pocp, mapping_ref
    //report_in = report_samp_data // group_meta, [ref_meta], [meta], [fastq], [reference], [sendsketch], [ref_stats], [quast]
    //    .join(report_variant_data, remainder: true) // group_meta, [ref_meta], [meta], [fastq], [reference], [sendsketch], [ref_stats], [quast], [ref_meta], [vcf], [align], [tree]
    //    .map { it.size() == 12 ? it : it[0..7] + [[], [], [], []] } // group_meta, [ref_meta], [meta], [fastq], [reference], [sendsketch], [ref_stats], [quast], [ref_meta], [vcf], [align], [tree]
    //    .join(report_group_data, remainder: true) // group_meta, [ref_meta], [meta], [fastq], [reference], [sendsketch], [ref_stats], [quast], [ref_meta], [vcf], [align], [tree], ani_matrix, [core_phylo], pocp, mapping_ref
    //    .map { it.size() == 16 ? it : it[0..11] + [[], [], [], []] } // group_meta, [ref_meta], [meta], [fastq], [reference], [sendsketch], [ref_stats], [quast], [ref_meta], [vcf], [align], [tree], ani_matrix, [core_phylo], pocp, mapping_ref
    //    .map { it[0..1] + it[5..7] + it[9..15] } // group_meta, [ref_meta], [sendsketch], [ref_stats], [quast], [vcf], [align], [tree], ani_matrix, [core_phylo], pocp, mapping_ref
    //    .map { [
    //        it[0],
    //        it[1].findAll{ it.id != null }.unique(),
    //        it[2],
    //        it[3],
    //        it[4].findAll{ it != null },
    //        it[5].findAll{ it != null },
    //        it[6].findAll{ it != null },
    //        it[7].findAll{ it != null },
    //        it[8],
    //        it[9] == null ? [] : it[9],
    //        it[10],
    //        it[11]
    //     ] } // group_meta, [ref_meta], [sendsketch], [ref_stats], [quast], [vcf], [align], [tree], ani_matrix, [core_phylo], pocp, mapping_ref

    //PREPARE_REPORT_INPUT (
    //    report_in,
    //    PREPARE_INPUT.out.csv,
    //    MULTIQC.out.data,
    //    MULTIQC.out.plots,
    //    MULTIQC.out.report,
    //    CUSTOM_DUMPSOFTWAREVERSIONS.out.yml.first(), // .first converts it to a value channel so it can be reused for multiple reports.
    //    RECORD_MESSAGES.out.tsv
    //)

    //MAIN_REPORT (
    //    PREPARE_REPORT_INPUT.out.report_input,
    //    Channel.fromPath("${projectDir}/assets/main_report", checkIfExists: true).first() // .first converts it to a value channel so it can be reused for multiple reports.
    //)

}










/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
