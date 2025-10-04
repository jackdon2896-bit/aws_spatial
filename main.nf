#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
========================================================================================
    AWS Spatial Transcriptomics Pipeline - FIXED VERSION
========================================================================================
    Spatial transcriptomics analysis with H5 or SRA data support
    GitHub: https://github.com/jackdon2896-bit/aws_spatial
----------------------------------------------------------------------------------------
*/

// Import modules
include { SRA_DOWNLOAD } from './modules/local/sra_download.nf'
include { FASTQ_TO_H5AD } from './modules/local/fastq_to_h5ad.nf'
include { H5_TO_H5AD } from './modules/local/h5_to_h5ad.nf'

// Parameters with defaults
params.tiff = null
params.h5 = null
params.sra_ids = null
params.outdir = "results"

// Parameter validation
if (!params.tiff) {
    error "ERROR: --tiff parameter is required (TIFF image file)"
}

if (!params.h5 && !params.sra_ids) {
    error "ERROR: Either --h5 or --sra_ids parameter is required"
}

if (!params.outdir) {
    error "ERROR: --outdir parameter is required"
}

/*
========================================================================================
    IMAGE PROCESSING PROCESSES
========================================================================================
*/

process PREPROCESS_IMAGE {
    tag "${tiff.name}"
    publishDir "${params.outdir}/preprocessed", mode: 'copy'

    input:
    path tiff

    output:
    path "filled.tif", emit: filled

    script:
    """
    python ${projectDir}/bin/preprocess_image.py ${tiff} filled.tif
    """
}

process CELLPOSE_SEGMENT {
    tag "cellpose"
    publishDir "${params.outdir}/segmentation", mode: 'copy'

    input:
    path filled

    output:
    path "mask.png", emit: mask

    script:
    """
    python ${projectDir}/bin/segment_cellpose.py ${filled} mask.png
    """
}

process AI_ROI_CROP {
    tag "roi_crop"
    publishDir "${params.outdir}/roi", mode: 'copy'

    input:
    path filled
    path mask

    output:
    path "roi.tif", emit: roi_img
    path "coords.csv", emit: coords

    script:
    """
    python ${projectDir}/bin/ai_roi_crop.py ${filled} ${mask} roi.tif coords.csv
    """
}

/*
========================================================================================
    scRNA-SEQ ANALYSIS PROCESSES
========================================================================================
*/

process SCRNA_QC {
    tag "qc"
    publishDir "${params.outdir}/qc", mode: 'copy'

    input:
    path h5ad

    output:
    path "qc.h5ad", emit: qc

    script:
    """
    python ${projectDir}/bin/qc.py ${h5ad} qc.h5ad
    """
}

process SCRNA_MAD_FILTER {
    tag "mad_filter"
    publishDir "${params.outdir}/filtered", mode: 'copy'

    input:
    path qc

    output:
    path "filtered.h5ad", emit: filtered

    script:
    """
    python ${projectDir}/bin/mad_filter.py ${qc} filtered.h5ad
    """
}

process SCRNA_DIM_REDUCTION {
    tag "dimred"
    publishDir "${params.outdir}/dimred", mode: 'copy'

    input:
    path filtered

    output:
    path "reduced.h5ad", emit: reduced

    script:
    """
    python ${projectDir}/bin/dim_reduction.py ${filtered} reduced.h5ad
    """
}

process SCRNA_CLUSTER {
    tag "cluster"
    publishDir "${params.outdir}/clustered", mode: 'copy'

    input:
    path reduced

    output:
    path "clustered.h5ad", emit: clustered

    script:
    """
    python ${projectDir}/bin/cluster.py ${reduced} clustered.h5ad
    """
}

process SCRNA_ANNOTATE {
    tag "annotate"
    publishDir "${params.outdir}/annotated", mode: 'copy'

    input:
    path clustered

    output:
    path "annotated.h5ad", emit: annotated

    script:
    """
    python ${projectDir}/bin/annotate_celltypist.py ${clustered} annotated.h5ad
    """
}

/*
========================================================================================
    SPATIAL ANALYSIS PROCESSES
========================================================================================
*/

process SPATIAL_REFINE {
    tag "spatial_refine"
    publishDir "${params.outdir}/refined", mode: 'copy'

    input:
    path annotated
    path coords

    output:
    path "refined.h5ad", emit: refined

    script:
    """
    python ${projectDir}/bin/spatial_refine.py ${annotated} refined.h5ad
    """
}

process SPATIAL_INTEGRATION {
    tag "spatial_integration"
    publishDir "${params.outdir}/integrated", mode: 'copy'

    input:
    path roi_img
    path refined

    output:
    path "integrated.h5ad", emit: integrated

    script:
    """
    python ${projectDir}/bin/spatial_integrate.py ${roi_img} ${refined} integrated.h5ad
    """
}

/*
========================================================================================
    OUTPUT PROCESSES
========================================================================================
*/

process SCRNA_PLOTS {
    tag "scrna_plots"
    publishDir "${params.outdir}/scrna_plots", mode: 'copy'

    input:
    path refined

    output:
    path "*.png", emit: plots

    script:
    """
    python ${projectDir}/bin/plots.py ${refined}
    """
}

process SPATIAL_PLOTS {
    tag "spatial_plots"
    publishDir "${params.outdir}/spatial_plots", mode: 'copy'

    input:
    path integrated

    output:
    path "*.png", emit: plots

    script:
    """
    python ${projectDir}/bin/plots.py ${integrated}
    """
}

process REPORT {
    tag "report"
    publishDir "${params.outdir}/report", mode: 'copy'

    input:
    path integrated

    output:
    path "report.md", emit: report

    script:
    """
    python ${projectDir}/bin/report.py ${integrated} report.md
    """
}

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow {
    
    // Create image channel
    tiff_ch = Channel.fromPath(params.tiff, checkIfExists: true)
    
    // Process image
    filled_ch = PREPROCESS_IMAGE(tiff_ch)
    mask_ch = CELLPOSE_SEGMENT(filled_ch)
    roi_result = AI_ROI_CROP(filled_ch, mask_ch)
    
    // Create H5AD channel based on input type
    if (params.sra_ids) {
        // SRA workflow
        sra_ids_ch = Channel.from(params.sra_ids.tokenize(','))
        sra_downloads = SRA_DOWNLOAD(sra_ids_ch)
        
        // Group FASTQ files by SRA ID and convert to H5AD
        sra_downloads.fastq
            .map { fastq -> 
                def sra_id = fastq.name.replaceAll('_.*', '')
                tuple(sra_id, fastq)
            }
            .groupTuple()
            .map { sra_id, fastq_files ->
                def meta = [id: sra_id]
                tuple(meta, fastq_files)
            }
            .set { fastq_grouped }
        
        h5ad_ch = FASTQ_TO_H5AD(fastq_grouped)
        
    } else if (params.h5) {
        // H5 workflow
        h5_ch = Channel.fromPath(params.h5, checkIfExists: true)
        h5ad_ch = H5_TO_H5AD(h5_ch)
    }
    
    // scRNA-seq analysis pipeline
    qc_ch = SCRNA_QC(h5ad_ch)
    filtered_ch = SCRNA_MAD_FILTER(qc_ch)
    reduced_ch = SCRNA_DIM_REDUCTION(filtered_ch)
    clustered_ch = SCRNA_CLUSTER(reduced_ch)
    annotated_ch = SCRNA_ANNOTATE(clustered_ch)
    
    // Spatial analysis
    refined_ch = SPATIAL_REFINE(annotated_ch, roi_result.coords)
    integrated_ch = SPATIAL_INTEGRATION(roi_result.roi_img, refined_ch)
    
    // Generate outputs
    SCRNA_PLOTS(refined_ch)
    SPATIAL_PLOTS(integrated_ch)
    REPORT(integrated_ch)
}

/*
========================================================================================
    COMPLETION MESSAGE
========================================================================================
*/

workflow.onComplete {
    log.info """
    ========================================================================================
    Pipeline execution completed!
    ========================================================================================
    Status      : ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Start time  : ${workflow.start}
    End time    : ${workflow.complete}
    Duration    : ${workflow.duration}
    Results     : ${params.outdir}
    ========================================================================================
    """.stripIndent()
}

workflow.onError {
    log.error """
    ========================================================================================
    Pipeline execution failed!
    ========================================================================================
    Error message: ${workflow.errorMessage}
    Error report : ${workflow.errorReport}
    ========================================================================================
    """.stripIndent()
}
