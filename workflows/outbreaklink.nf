/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_outbreaklink_pipeline'
include { ALL_ALLELES            } from '../modules/local/all_alleles.nf'
include { REFERENCE_ALLELES      } from '../modules/local/reference_alleles.nf'
include { ALLELES_REFORMAT       } from '..//modules/local/alleles_reformat.nf'
include { ETOKI_DB               } from '../modules/local/etoki_index_main'
include { ETOKI_MLST             } from '../modules/local/etoki_mlst_main'
include { FASTANI_PREP           } from '../modules/local/fastani_prep'
include { FASTANI                } from '../modules/nf-core/fastani/main'
include { ETOKI_PREP             } from '../modules/local/etoki_prep'
include { MLST_JACCARD           } from '../modules/local/mlst_jaccard'
include {MLST_JACCARD_COMBIND    } from '../modules/local/mlst_jaccard_combind'
include {GENERATE_SIF            } from '../modules/local/generate_sif'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow OUTBREAKLINK {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_assemblies = Channel.empty()

    //
    // MODULE: Run FastQC
    //
    // FASTQC (
        // ch_samplesheet
    // )
    // ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    // ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    //ch_input = Channel.fromPath(params.input)
    
    //ch_samplesheet.view()

    // ch_assemblies  = ch_samplesheet(RUN_18S.out.blast_results)
    // ch_ssu_results_18S.view()
    // ch_assemblies = ch_samplesheet.map { string -> string }.collect()
    // ch_assemblies.view()

    //ALL_ALLELES("${params.reference_fastas}")
    REFERENCE_ALLELES("${params.reference_fastas}")
    ch_ref_alleles = REFERENCE_ALLELES.out.reference_alleles
    ALLELES_REFORMAT("${params.reference_fastas}")
    //ch_etoki_alleles = Channel.empty()
    ch_etoki_prep_f1 = Channel.empty()
    ch_etoki_prep_f2 = Channel.empty()
    

    ETOKI_DB(ALLELES_REFORMAT.out.alleles_reformat,ch_ref_alleles)
    ETOKI_MLST(ch_samplesheet,ch_ref_alleles,ETOKI_DB.out.etoki_csv)
    FASTANI_PREP("${params.input}")
    FASTANI(FASTANI_PREP.out.fastani_prepfile)
    ETOKI_PREP(ETOKI_MLST.out.etoki_alleles_fasta.collect{it[1]})
    ch_etoki_prep_f1 = ETOKI_PREP.out.etoki_prepfile
    MLST_JACCARD(ch_etoki_prep_f1)
    MLST_JACCARD_COMBIND(MLST_JACCARD.out.mlst_jaccard_distance)
    params.percentage = params.percentage ?: 99.850 
    GENERATE_SIF(FASTANI.out.ani, params.percentage)




    






    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
