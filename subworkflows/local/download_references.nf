include { FIND_ASSEMBLIES                           } from '../../modules/local/find_assemblies'
include { MERGE_ASSEMBLIES                          } from '../../modules/local/merge_assemblies'
include { PICK_ASSEMBLIES                           } from '../../modules/local/pick_assemblies'
include { DOWNLOAD_ASSEMBLIES                       } from '../../modules/local/download_assemblies'
include { MAKE_GFF_WITH_FASTA                       } from '../../modules/local/make_gff_with_fasta'
include { SOURMASH_SKETCH as SOURMASH_SKETCH_GENOME } from '../../modules/nf-core/sourmash/sketch/main'
include { KHMER_TRIMLOWABUND                        } from '../../modules/local/khmer_trimlowabund'

workflow DOWNLOAD_REFERENCES {

    take:

    ch_species  // sample_meta, taxa
    ch_genera   // sample_meta, taxa
    ch_families // sample_meta, taxa
    sample_data // sample_meta, [read_paths], report_meta, [ref_metas]

    main:

    // Initalize channel to accumulate information about software versions used
    versions = Channel.empty()

    // Get list of families for all samples without exclusive references defined by the user
    all_families = sample_data
        .filter { sample_meta, read_paths, report_meta, ref_metas ->
            ! ref_metas.map{it.id}.contains('exclusive')
        }
        .join(ch_families)
        .map { sample_meta, read_paths, report_meta, ref_metas, families ->
            [families]
        }
        .splitText()
        .map { it.replace('\n', '') }
        .collect()
        .toSortedList()
        .flatten()
        .unique()

    // Download RefSeq metadata for all assemblies for every family found by the initial identification
    FIND_ASSEMBLIES ( all_families )
    versions = versions.mix(FIND_ASSEMBLIES.out.versions.toSortedList().map{it[0]})

    // Choose reference sequences to provide context for each sample
    PICK_ASSEMBLIES (
        ch_families
            .join(ch_genera)
            .join(ch_species),
        FIND_ASSEMBLIES.out.stats
            .map { it[1] }
            .toSortedList(),
        params.n_ref_strains,
        params.n_ref_species,
        params.n_ref_genera
    )

    // Make channel with all unique assembly IDs
    user_acc_list = sample_data
        .map { [it[3], it[5]] } // ref_meta, reference_refseq
        .unique()
    ch_assembly_ids = PICK_ASSEMBLIES.out.id_list
        .map {it[1]}
        .splitText()
        .map { it.replace('\n', '') }
        .filter { it != '' }
        .map { it.split('\t') }
        .map { [[id: it[0], name: it[2]], it[1]] }
        .unique()
        .join(user_acc_list, by:1, remainder: true) // this is used to provide something for the following filter to work
        .filter {it[2] == null} // remove any user-defined accession numbers that have already been downloaded
        .map { it[1..0] }
        .unique()
    DOWNLOAD_ASSEMBLIES ( ch_assembly_ids )
    versions = versions.mix(DOWNLOAD_ASSEMBLIES.out.versions.toSortedList().map{it[0]})

    // Add sequence to the gff
    MAKE_GFF_WITH_FASTA (
        DOWNLOAD_ASSEMBLIES.out.sequence
            .join(DOWNLOAD_ASSEMBLIES.out.gff)
    )

    SOURMASH_SKETCH_GENOME ( DOWNLOAD_ASSEMBLIES.out.sequence )
    versions = versions.mix(SOURMASH_SKETCH_GENOME.out.versions.toSortedList().map{it[0]})

    genome_ids = PICK_ASSEMBLIES.out.id_list
        .splitText(elem: 1)
        .map { [[id: it[1].replace('\n', '').split('\t')[0], name: it[1].replace('\n', '').split('\t')[2]], it[0]] } // [ val(ref_meta), val(meta) ]

    emit:
    assem_samp_combos = genome_ids                        // ref_meta, meta for each assembly/sample combination
    sequence   = DOWNLOAD_ASSEMBLIES.out.sequence         // ref_meta, fna for each assembly
    gff        = MAKE_GFF_WITH_FASTA.out.gff              // ref_meta, gff for each assembly
    signatures = SOURMASH_SKETCH_GENOME.out.signatures    // ref_meta, signature for each assembly
    stats      = PICK_ASSEMBLIES.out.stats                // stats for each sample
    stats_all  = PICK_ASSEMBLIES.out.merged_stats.first() // merged_stats
    versions   = versions                              // versions.yml
}
