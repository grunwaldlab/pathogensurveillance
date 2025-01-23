include { BUSCO                     } from '../../modules/local/busco/busco/main'
include { BUSCO_DOWNLOAD            } from '../../modules/local/busco_download'
include { ASSIGN_CONTEXT_REFERENCES } from '../../modules/local/assign_context_references'
include { MAFFT as MAFFT_SMALL      } from '../../modules/nf-core/mafft/main'
include { IQTREE2 as IQTREE2_CORE   } from '../../modules/local/iqtree2'
include { SUBSET_BUSCO_GENES        } from '../../modules/local/subset_busco_genes'
include { FILES_IN_DIR              } from '../../modules/local/files_in_dir'

workflow BUSCO_PHYLOGENY {

    take:
    original_sample_data
    ani_matrix // report_group_id, ani_matrix
    sample_assemblies

    main:

    versions = Channel.empty()
    messages = Channel.empty()

    // Remove any samples that are not eukaryotes
    sample_data = original_sample_data
        .filter{it.kingdom == "Eukaryota"}

    // Make file with sample IDs and user-defined references or NA for each group
    samp_ref_pairs = sample_data
        .map{ [it.sample_id, it.report_group_ids, it.ref_metas] }
        .transpose(by: 2)
        .map{ sample_id, report_group_id, ref_meta ->
            [sample_id, report_group_id, ref_meta.ref_id, ref_meta.ref_name, ref_meta.ref_description, ref_meta.ref_path, ref_meta.ref_primary_usage]
        }
        .unique()
        .collectFile() { sample_id, report_group_id, ref_id, ref_name, ref_desc, ref_path, usage ->
            [ "${report_group_id}.csv", "${sample_id},${ref_id},${ref_name},${ref_desc},${usage}\n" ]
        }
        .map {[[id: it.getSimpleName()], it]}

    // Assign referneces to groups for context in phylogenetic analyses
    ASSIGN_CONTEXT_REFERENCES (
        ani_matrix.combine(samp_ref_pairs, by: 0),
        params.n_ref_closest,
        params.n_ref_closest_named,
        params.n_ref_context
    )
    versions = versions.mix(ASSIGN_CONTEXT_REFERENCES.out.versions)

    // Create channel with required reference metadata and genomes from selected references
    references =  sample_data
        .map{ [[id: it.report_group_ids], it.ref_metas] }
        .transpose(by: 1)
        .map{ report_meta, ref_meta ->
            [report_meta, [id: ref_meta.ref_id], ref_meta.ref_path, ref_meta.ref_name]
        }
        .unique()

    selected_ref_data = ASSIGN_CONTEXT_REFERENCES.out.references
        .splitText( elem: 1 )
        .map { [it[0], it[1].replace('\n', '')] } // remove newline that splitText adds
        .splitCsv( elem: 1 )
        .map { report_meta, csv_contents ->
            [report_meta, [id: csv_contents[0]]]
        }
        .combine(references, by: 0..1)
        .map {report_meta, ref_meta, ref_path, ref_name ->
            [[id: ref_meta.id], report_meta, ref_path]
        }

    // Combine selected reference data with analogous sample metadata and assembled genomes
    busco_input = sample_data
        .map{ [[id: it.sample_id], [id: it.report_group_ids]] }
        .combine(sample_assemblies, by: 0)
        .mix(selected_ref_data)

    // Download BUSCO datasets
    BUSCO_DOWNLOAD ( Channel.from( "eukaryota_odb10" ) )
    versions = versions.mix(BUSCO_DOWNLOAD.out.versions)

    // Extract BUSCO genes for all unique reference genomes used in any sample/group
    BUSCO (
        busco_input
            .map{ meta, report_meta, path ->
                [meta, path]
            }
            .unique(),
        "genome",
        "eukaryota_odb10",
        BUSCO_DOWNLOAD.out.download_dir.first(), // .first() is needed to convert the queue channel to a value channel so it can be used multiple times.
        []
    )
    versions = versions.mix(BUSCO.out.versions)


    // Combine BUSCO output by gene for each report group
    sorted_busco_data = busco_input
        .combine(BUSCO.out.busco_dir, by: 0)
        .map{ meta, report_meta, path, busco_dir ->
            [report_meta, busco_dir]
        }
        .groupTuple(by: 0, sort: 'hash')
        .combine(samp_ref_pairs, by: 0)
    SUBSET_BUSCO_GENES (
        sorted_busco_data,
        params.phylo_min_genes,
        params.phylo_max_genes
    )

    // Report any sample or references that have been removed from the analysis
    removed_refs = SUBSET_BUSCO_GENES.out.removed_ref_ids
        .splitText()
        .map { [null, [id: it[1].replace('\n', '')], it[0], "CORE_GENOME_PHYLOGENY", "WARNING", "Reference removed from core gene phylogeny in order to find enough core genes."] } // meta, group_meta, ref_meta, workflow, level, message
    removed_samps = SUBSET_BUSCO_GENES.out.removed_sample_ids
        .splitText()
        .map { [[id: it[1].replace('\n', '')], it[0], null, "CORE_GENOME_PHYLOGENY", "WARNING", "Sample removed from core gene phylogeny in order to find enough core genes."] } // meta, group_meta, ref_meta, workflow, level, message
    messages = messages.mix(removed_refs)
    messages = messages.mix(removed_samps)

    // Align each gene family with mafft
    core_genes = SUBSET_BUSCO_GENES.out.feat_seqs
        .transpose()
        .map { [[id: "${it[0].id}_${it[1].baseName}", group_id: it[0]], it[1]] }
    FILES_IN_DIR ( core_genes )
    MAFFT_SMALL ( FILES_IN_DIR.out.files.transpose(), [[], []], [[], []], [[], []], [[], []], [[], []], false )
    versions = versions.mix(MAFFT_SMALL.out.versions)

    // Inferr phylogenetic tree from aligned core genes
    IQTREE2_CORE ( MAFFT_SMALL.out.fas.groupTuple(sort: 'hash'), [] )
    versions = versions.mix(IQTREE2_CORE.out.versions)
    trees = IQTREE2_CORE.out.phylogeny // subset_meta, tree
        .map { [it[0].group_id, it[1]] } // group_meta, tree
        .groupTuple(sort: 'hash') // group_meta, [trees]

    emit:
    versions      = versions // versions.yml
    messages      = messages // meta, group_meta, ref_meta, workflow, level, message
    selected_refs = ASSIGN_CONTEXT_REFERENCES.out.references
    tree          = trees

}
