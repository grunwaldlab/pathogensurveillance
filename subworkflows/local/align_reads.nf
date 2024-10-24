include { BWA_MEM                            } from '../../modules/nf-core/bwa/mem/main'
include { PICARD_ADDORREPLACEREADGROUPS      } from '../../modules/nf-core/picard/addorreplacereadgroups/main'
include { PICARD_SORTSAM as PICARD_SORTSAM_1 } from '../../modules/nf-core/picard/sortsam/main'
include { PICARD_SORTSAM as PICARD_SORTSAM_2 } from '../../modules/nf-core/picard/sortsam/main'
include { PICARD_MARKDUPLICATES              } from '../../modules/nf-core/picard/markduplicates/main'
include { SAMTOOLS_INDEX                     } from '../../modules/nf-core/samtools/index/main'
include { CALCULATE_DEPTH                    } from '../../modules/local/calculate_depth'
include { SUBSET_READS                       } from '../../modules/local/subset_reads'

workflow ALIGN_READS {

    take:
    ch_input     // channel: [ val(meta), [ fastq_1, fastq_2 ], ref_meta, reference, reference_index, bam_index ]

    main:

    versions = Channel.empty()

    samp_ref_combo1 = ch_input
        .map { [[id: "${it[2].id}_${it[0].id}", ref: it[2], sample: it[0]]] + it } // make composite ID for read/ref combos

    ch_reads_and_ref = samp_ref_combo1.map { [it[0], it[2], it[4]] }
    CALCULATE_DEPTH ( ch_reads_and_ref )
    SUBSET_READS (
        ch_reads_and_ref
            .map { it[0..1] }
            .combine(CALCULATE_DEPTH.out.depth, by:0),
        params.variant_max_depth
    )
    versions = versions.mix(SUBSET_READS.out.versions)

    samp_ref_combo2 = samp_ref_combo1
        .combine(SUBSET_READS.out.reads, by:0) // ref_samp_meta, meta, [reads], ref_meta, reference, reference_index, bam_index, [reads_subset]
        .map { it[0..1] + [it[7]] + it[3..6] } // ref_samp_meta, meta, [reads_subset], ref_meta, reference, reference_index, bam_index

    ch_reads = samp_ref_combo2
        .map { [it[0], it[2] instanceof Collection && it[2].size() > 2 ? it[2][0..1] : it[2]] } // NOTE: not sure why there are sometimes more than 2 read files. Might need to change once long reads are fullly supported
    ch_bwa_index = samp_ref_combo2.map { [it[0], it[6]] }
    BWA_MEM ( ch_reads, ch_bwa_index, false )
    versions = versions.mix(BWA_MEM.out.versions)

    PICARD_ADDORREPLACEREADGROUPS ( BWA_MEM.out.bam )
    versions = versions.mix(PICARD_ADDORREPLACEREADGROUPS.out.versions)

    PICARD_SORTSAM_1 ( PICARD_ADDORREPLACEREADGROUPS.out.bam, 'coordinate' )
    versions = versions.mix(PICARD_SORTSAM_1.out.versions)

    ch_reference = samp_ref_combo2.map { [it[0], it[4]] } // channel: [ val(ref_samp_meta), file(reference) ]
    ch_ref_index = samp_ref_combo2.map { [it[0], it[5]] } // channel: [ val(ref_samp_meta), file(ref_index) ]
    picard_input = PICARD_SORTSAM_1.out.bam // joined to associated right reference with each sample
        .join(ch_reference)
        .join(ch_ref_index)

    PICARD_MARKDUPLICATES (
        picard_input.map { it[0..1] },
        picard_input.map { [it[0], it[2]] },
        picard_input.map { [it[0], it[3]] }
    )
    versions = versions.mix(PICARD_MARKDUPLICATES.out.versions)

    PICARD_SORTSAM_2 ( PICARD_MARKDUPLICATES.out.bam, 'coordinate' )

    SAMTOOLS_INDEX ( PICARD_SORTSAM_2.out.bam )
    versions = versions.mix(SAMTOOLS_INDEX.out.versions)

    // Revet combined metas back to seperate ones for sample and reference
    out_bam = PICARD_SORTSAM_2.out.bam        // channel: [ val(ref_samp_meta), [ bam ] ]
        .map { [it[0].sample, it[0].ref, it[1]] }
    out_bai = SAMTOOLS_INDEX.out.bai        // channel: [ val(ref_samp_meta), [ bai ] ]
        .map { [it[0].sample, it[0].ref, it[1]] }


    emit:
    bam      = out_bam        // channel: [ val(meta), val(ref_meta), [ bam ] ]
    bai      = out_bai        // channel: [ val(meta), val(ref_meta), [ bai ] ]
    versions = versions    // channel: [ versions.yml ]
}

