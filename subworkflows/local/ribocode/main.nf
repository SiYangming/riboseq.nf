//
// Check input samplesheet and get read channels
//

include { RIBOCODE_GTFUPDATE } from '../../../modules/nf-core/ribocode/gtfupdate/main'
include { RIBOCODE_PREPARE   } from '../../../modules/nf-core/ribocode/prepare/main'
include { RIBOCODE_METAPLOTS } from '../../../modules/nf-core/ribocode/metaplots/main'
include { RIBOCODE_RIBOCODE  } from '../../../modules/nf-core/ribocode/ribocode/main'

workflow RIBOCODE {

    take:
    ch_bam          // channel: [ val(meta), [ bam ] ]
    ch_fasta        // channel: [ val(meta), [ fasta ] ]
    ch_gtf          // channel: [ val(meta), [ gtf ] ]

    main:

    ch_versions = Channel.empty()

    //
    // Update GTF file for RiboCode compatibility
    //
    RIBOCODE_GTFUPDATE (
        ch_gtf
    )
    ch_versions = ch_versions.mix(RIBOCODE_GTFUPDATE.out.versions_ribocode)

    //
    // Prepare annotation files
    //
    RIBOCODE_PREPARE (
        ch_fasta,
        RIBOCODE_GTFUPDATE.out.gtf
    )
    ch_versions = ch_versions.mix(RIBOCODE_PREPARE.out.versions_ribocode)

    //
    // Generate metaplots and P-site configuration
    //
    RIBOCODE_METAPLOTS (
        ch_bam,
        RIBOCODE_PREPARE.out.annotation
    )
    ch_versions = ch_versions.mix(RIBOCODE_METAPLOTS.out.versions_ribocode)

    //
    // Call ORFs using RiboCode
    //
    ch_ribocode_input = ch_bam.join(RIBOCODE_METAPLOTS.out.config)

    ch_ribocode_input
        .multiMap { meta, bam, config ->
            bam: [ meta, bam ]
            config: [ meta, config ]
        }
        .set { ch_ribocode_input_split }

    RIBOCODE_RIBOCODE (
        ch_ribocode_input_split.bam,
        RIBOCODE_PREPARE.out.annotation,
        ch_ribocode_input_split.config
    )
    ch_versions = ch_versions.mix(RIBOCODE_RIBOCODE.out.versions_ribocode)

    emit:
    orf_txt            = RIBOCODE_RIBOCODE.out.orf_txt
    orf_txt_collapsed  = RIBOCODE_RIBOCODE.out.orf_txt_collapsed
    orf_pdf            = RIBOCODE_RIBOCODE.out.orf_pdf
    psites_hd5         = RIBOCODE_RIBOCODE.out.psites_hd5
    metaplots_pdf      = RIBOCODE_METAPLOTS.out.pdf
    versions           = ch_versions
}
