/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { SAMTOOLS_VIEW } from '../modules/nf-core/samtools/view/main'    
include { BEDTOOLS_INTERSECT     } from '../modules/nf-core/bedtools/intersect/main'   
include { BEDTOOLS_INTERSECT as BEDTOOLS_INTERSECT_CNTRL    } from '../modules/nf-core/bedtools/intersect/main'   
include { HOMER_PEAKCALLING      } from '../subworkflows/local/homer_peakcalling/main'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_homer_peakcalling_from_bam_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow HOMER_PEAKCALLING_FROM_BAM {

    take:
    ch_bam
    ch_fasta
    ch_gtf
    ch_control_bam
    ch_blacklist

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_peakcalling_bams = Channel.empty()

    SAMTOOLS_VIEW(
        ch_bam.map { meta, bam -> [meta, bam, []] },
        ch_fasta.map { fasta -> [[:], fasta] },
        [],  // qname
        "bai"
    )
    ch_peakcalling_bams = SAMTOOLS_VIEW.out.bam
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW.out.versions.first())

    // the control for chipexo doesn't need to be passed through b/c it is
    // already filtered


    if (ch_blacklist) {
        BEDTOOLS_INTERSECT(
            ch_peakcalling_bams.combine(ch_blacklist).map { meta, bam, bed -> [meta, bam, bed] },
            [[:],[]]  // BEDTOOLS_INTERSECT doesn't need fasta/chrom_sizes
        )
        ch_peakcalling_bams = BEDTOOLS_INTERSECT.out.intersect
        ch_versions = ch_versions.mix(BEDTOOLS_INTERSECT.out.versions.first())

        if (ch_control_bam) {
            BEDTOOLS_INTERSECT_CNTRL(
                ch_control_bam.combine(ch_blacklist).map { meta, bam, bed -> [meta, bam, bed] },
                [[:],[]]  // BEDTOOLS_INTERSECT doesn't need fasta/chrom_sizes
            )
            ch_control_bam = BEDTOOLS_INTERSECT_CNTRL.out.intersect
        }
    }


    HOMER_PEAKCALLING (
        Channel.value("factor"),
        ch_peakcalling_bams,
        [], // tagdir
        ch_fasta,
        ch_gtf,
        ch_control_bam,
        [], // control_tagdir
        [], // uniqmap
        params.merge_peaks,
        params.annotate_individual,
        params.quantify_peaks,
        params.make_bedgraph
    )

    // ch_promoter_enrichment = (tagdir ?: HOMER_PEAKCALLING.out.tagdir)
    // .mix(control_tagdir ?: HOMER_PEAKCALLING.out.control_tagdir)
    // HOMER_ANNOTATEPEAKS (
    //     ch_promoter_enrichment,
    //     ch_gtf
    // )
    // todo: there should be a report output channel from homer_peakcalling
    ch_versions = ch_versions.mix(HOMER_PEAKCALLING.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(HOMER_PEAKCALLING.out.tagdir.map(it -> it[1]))
    ch_multiqc_files = ch_multiqc_files.mix(HOMER_PEAKCALLING.out.txt.map(it -> it[1]))
    ch_multiqc_files = ch_multiqc_files.mix(HOMER_PEAKCALLING.out.merged_txt.map(it -> it[1]))
    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name:  'homer_peakcalling_from_bam_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
