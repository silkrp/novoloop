/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_novoloop_pipeline'

include { FASTPLONG             } from '../modules/local/fastplong/main'
include { SAMTOOLS_VIEW         } from '../modules/local/samtools/view/main'
include { BEDTOOLS_BAMTOFASTQ   } from '../modules/local/bedtools/bamtofastq/main'

include { FLYE              } from '../modules/local/flye/main'
include { MEDAKA            } from '../modules/nf-core/medaka/main'
include { GUNZIP            } from '../modules/nf-core/gunzip/main'
include { FASTP             } from '../modules/local/fastp/main'
include { NEXTPOLISH        } from '../modules/local/nextpolish/main'
include { MINIMAP2_INDEX    } from '../modules/nf-core/minimap2/index/main'
include { MINIMAP2_ALIGN    } from '../modules/local/minimap2/align/main'

include { BEDTOOLS_BAMTOBED as BEDTOOLS_BAMTOBED_BED   } from '../modules/local/bedtools/bamtobed/main'
include { BEDTOOLS_BAMTOBED as BEDTOOLS_BAMTOBED_BED12 } from '../modules/local/bedtools/bamtobed/main'

// include { BANDAGE_IMAGE     } from '../modules/nf-core/bandage/image/main'
// include { STRAINY           } from '../modules/local/strainy/main'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NOVOLOOP {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    ch_reference

    main: 

    //
    // Run FASTPLONG for long read pre-processing
    //
    ch_lr_samplesheet = ch_samplesheet
        .map({ meta, lr_fastq, lr_bam, lr_index, lr_cnvs, sr_fastq1, sr_fastq2 -> [ meta, lr_fastq ] })

    ch_sr_samplesheet = ch_samplesheet
        .map({ meta, lr_fastq, lr_bam, lr_index, lr_cnvs, sr_fastq1, sr_fastq2 -> [ meta, sr_fastq1, sr_fastq2 ] })
    
    FASTPLONG (
        ch_lr_samplesheet
    )

    //
    // Run read preprocessing of long reads
    //
    if ( params.bam ) {

        samtools_view_input = ch_samplesheet
            .map({ meta, lr_fastq, lr_bam, lr_index, lr_cnvs, sr_fastq1, sr_fastq2 -> [ meta, lr_bam, lr_index, lr_cnvs ] })

        SAMTOOLS_VIEW (
            samtools_view_input
        )

        BEDTOOLS_BAMTOFASTQ (
            SAMTOOLS_VIEW.out.bam
        )

        preprocessed_reads = BEDTOOLS_BAMTOFASTQ.out.fastq

    } else {

        preprocessed_reads = FASTPLONG.out.reads

    }

    //
    // Run de-novo assembly
    //
    FLYE (
        preprocessed_reads,
        "--nano-hq"
    )

    //
    // Long read polishing
    //
    medaka_input = FASTPLONG.out.reads
        .join(FLYE.out.fasta)

    MEDAKA (
        medaka_input
    )

    //
    // FASTP for short-read pre-processing
    // 
    FASTP (
        ch_sr_samplesheet
    )

    //
    // Unzip fastq file
    //
    GUNZIP (
        MEDAKA.out.assembly
    )

    //
    // Short read polishing
    //
    // this needs to be the format [meta, [R1.fastq, R2.fastq], assembly]
    nextpolish_input = FASTP.out.fastq
        .join(GUNZIP.out.gunzip)

    NEXTPOLISH (
        nextpolish_input
    )

    // 
    // Strainy to get different ecDNAs? 
    //

    //
    // Index reference genome
    //
    MINIMAP2_INDEX (
        ch_reference
    )  

    //
    // Realign contigs back to reference genome
    //
    MINIMAP2_ALIGN (
        NEXTPOLISH.out.assembly,
        MINIMAP2_INDEX.out.index, 
        true,
        'bai',
        false,
        false
    )

    //
    // Get mapping locations of circular contigs
    //
    BEDTOOLS_BAMTOBED_BED (
        MINIMAP2_ALIGN.out.bam,
        false
    )

    BEDTOOLS_BAMTOBED_BED12 (
        MINIMAP2_ALIGN.out.bam,
        true
    )



    // //
    // // Visualise genome graph
    // //
    // BANDAGE_IMAGE (
        
    // )




    ch_versions = Channel.empty()

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'novoloop_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
