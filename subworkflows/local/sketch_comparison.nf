include { KHMER_TRIMLOWABUND                          } from '../../modules/local/khmer_trimlowabund'
include { ASSIGN_MAPPING_REFERENCE                    } from '../../modules/local/assign_mapping_reference'
include { ASSIGN_CONTEXT_REFERENCES                   } from '../../modules/local/assign_context_references'
include { SOURMASH_SKETCH as SOURMASH_SKETCH_READS    } from '../../modules/nf-core/sourmash/sketch/main'
include { SOURMASH_SKETCH as SOURMASH_SKETCH_GENOME   } from '../../modules/nf-core/sourmash/sketch/main'
include { SOURMASH_COMPARE                            } from '../../modules/local/sourmash_compare'
include { SUBSET_READS                                } from '../../modules/local/subset_reads'

workflow SKETCH_COMPARISON {

    take:
    sample_data

    main:
    versions = Channel.empty()
    messages = Channel.empty()

    // Subset sample reads to increase speed of following steps
    SUBSET_READS (
        sample_data
            .map { [[id: it.sample_id], it.paths, it.sendsketch_depth] }
            .unique(),
        params.sketch_max_depth
    )
    versions = versions.mix(SUBSET_READS.out.versions)

    // Trim rare k-mers from raw reads
    KHMER_TRIMLOWABUND (
        SUBSET_READS.out.reads
    )
    versions = versions.mix(KHMER_TRIMLOWABUND.out.versions)

    // Create signature for each sample
    SOURMASH_SKETCH_READS (
        KHMER_TRIMLOWABUND.out.sequence
    )
    versions = versions.mix(SOURMASH_SKETCH_READS.out.versions)

    // Create signature for each reference genome
    references = sample_data
        .map{ [it.ref_metas] }
        .transpose(by: 0)
        .map{ ref_meta -> [[id: ref_meta[0].ref_id], ref_meta[0].ref_path] }
        .unique()
    SOURMASH_SKETCH_GENOME (
        references
    )
    versions = versions.mix(SOURMASH_SKETCH_GENOME.out.versions)

    // Compare all genomes/samples to eachother to create an ANI matrix
    grouped_sample_sigs = sample_data
        .map { [[id: it.sample_id], [id: it.report_group_ids]] }
        .combine(SOURMASH_SKETCH_READS.out.signatures, by:0)
        .map { sample_id, report_group_id, signature -> [report_group_id, signature]}
        .unique()
    grouped_ref_sigs = sample_data
        .map{ [it.ref_metas, [id: it.report_group_ids]] }
        .transpose(by: 0)
        .map{ ref_meta, report_group_id -> [[id: ref_meta.ref_id], report_group_id] }
        .combine(SOURMASH_SKETCH_GENOME.out.signatures, by: 0)
        .map{ ref_id, report_group_id, signature -> [report_group_id, signature]}
        .unique()
    grouped_sigs = grouped_sample_sigs
        .mix(grouped_ref_sigs)
        .groupTuple()
    SOURMASH_COMPARE (
        grouped_sigs,
        [], // file_list (optional)
        true, // save numpy matrix
        true  // save CSV
    )
    versions = versions.mix(SOURMASH_COMPARE.out.versions)

    emit:
    ani_matrix    = SOURMASH_COMPARE.out.csv                   // group_meta, csv
    versions      = versions                                // versions
    messages      = messages                                   // meta, group_meta, ref_meta, workflow, level, message
}
