nextflow.enable.dsl = 2

params.tiff = ""
params.h5 = ""
params.sra_ids = ""
params.outdir = ""

process {
    container = '644685128986.dkr.ecr.us-east-1.amazonaws.com/seqera/container-spatial:latest'
}

// Include local modules
include { SRA_DOWNLOAD } from './modules/local/sra_download.nf'
include { FASTQ_TO_H5AD } from './modules/local/fastq_to_h5ad.nf'
include { H5_TO_H5AD } from './modules/local/h5_to_h5ad.nf'

process PREPROCESS_IMAGE {
    publishDir "${params.outdir}/preprocessed", mode: 'copy'
    
    input:
    path tiff
    
    output:
    path "filled.tif"
    
    script:
    """
    python ${projectDir}/bin/preprocess_image.py ${tiff} filled.tif
    """
}

process CELLPOSE_SEGMENT {
    publishDir "${params.outdir}/segmentation", mode: 'copy'
    
    input:
    path filled
    
    output:
    path "mask.png"
    
    script:
    """
    python ${projectDir}/bin/segment_cellpose.py ${filled} mask.png
    """
}

process AI_ROI_CROP {
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

process SCRNA_QC {
    publishDir "${params.outdir}/qc", mode: 'copy'
    
    input:
    path h5
    
    output:
    path "qc.h5ad"
    
    script:
    """
    python ${projectDir}/bin/qc.py ${h5}
    """
}

process SCRNA_MAD_FILTER {
    publishDir "${params.outdir}/filtered", mode: 'copy'
    
    input:
    path qc
    
    output:
    path "filtered.h5ad"
    
    script:
    """
    python ${projectDir}/bin/mad_filter.py ${qc} filtered.h5ad
    """
}

process SCRNA_DIM_REDUCTION {
    publishDir "${params.outdir}/dimred", mode: 'copy'
    
    input:
    path filtered
    
    output:
    path "reduced.h5ad"
    
    script:
    """
    python ${projectDir}/bin/dim_reduction.py ${filtered} reduced.h5ad
    """
}

process SCRNA_CLUSTER {
    publishDir "${params.outdir}/clusters", mode: 'copy'
    
    input:
    path reduced
    
    output:
    path "clustered.h5ad"
    
    script:
    """
    python ${projectDir}/bin/cluster.py ${reduced} clustered.h5ad
    """
}

process SCRNA_ANNOTATE {
    publishDir "${params.outdir}/annotated", mode: 'copy'
    
    input:
    path clustered
    
    output:
    path "annotated.h5ad"
    
    script:
    """
    python ${projectDir}/bin/annotate_celltypist.py ${clustered} annotated.h5ad
    """
}

process SPATIAL_REFINE {
    publishDir "${params.outdir}/refined", mode: 'copy'
    
    input:
    path annot
    path coords
    
    output:
    path "refined.h5ad"
    
    script:
    """
    python ${projectDir}/bin/spatial_refine.py ${annot} refined.h5ad
    """
}

process SPATIAL_INTEGRATION {
    publishDir "${params.outdir}/integrated", mode: 'copy'
    
    input:
    path roi_img
    path refined
    
    output:
    path "integrated.h5ad"
    
    script:
    """
    python ${projectDir}/bin/spatial_integrate.py ${roi_img} ${refined} integrated.h5ad
    """
}

process SCRNA_PLOTS {
    publishDir "${params.outdir}/plots", mode: 'copy'
    
    input:
    path refined
    
    output:
    path "celltype.png"
    path "refined.png"
    path "heatmap.png"
    
    script:
    """
    python ${projectDir}/bin/plots.py ${refined}
    """
}

process SPATIAL_PLOTS {
    publishDir "${params.outdir}/spatial_plots", mode: 'copy'
    
    input:
    path integrated
    
    output:
    path "spatial_*.png"
    
    script:
    """
    python ${projectDir}/bin/plots.py ${integrated}
    """
}

process REPORT {
    publishDir "${params.outdir}/report", mode: 'copy'
    
    input:
    path integrated
    
    output:
    path "report.md"
    
    script:
    """
    python ${projectDir}/bin/report.py
    """
}

workflow {
    // Input channels
    def tiff_ch = channel.fromPath(params.tiff)
    
    // Handle H5 input - can be direct file or from SRA conversion
    def h5_ch = params.h5 ? channel.fromPath(params.h5) : channel.empty()
    
    // SRA processing branch (optional)
    def sra_h5_ch = channel.empty()
    if (params.sra_ids) {
        def sra_ids_ch = channel.fromList(params.sra_ids.split(',').collect { it.trim() })
        def sra_fastq = SRA_DOWNLOAD(sra_ids_ch)
        
        // Convert FASTQ to H5AD format
        def sra_meta_ch = sra_fastq.fastq.map { fastq_files ->
            def sra_id = fastq_files[0].name.split('_')[0]
            [['id': sra_id], fastq_files]
        }
        sra_h5_ch = FASTQ_TO_H5AD(sra_meta_ch).h5ad
    }
    
    // NEW: Handle H5 to H5AD conversion
    // Split inputs by file extension
    def h5_only_ch = h5_ch.filter { it.name.endsWith(".h5") }
    def h5ad_only_ch = h5_ch.filter { it.name.endsWith(".h5ad") }
    
    // Convert .h5 → .h5ad
    def converted_h5ad_ch = channel.empty()
    if (params.h5 && params.h5.endsWith(".h5")) {
        converted_h5ad_ch = H5_TO_H5AD(h5_only_ch).h5ad
    }
    
    // Combine all H5AD sources (existing .h5ad + converted .h5 + SRA-derived)
    def combined_h5_ch = h5ad_only_ch.mix(converted_h5ad_ch, sra_h5_ch)
    
    // IMAGE PROCESSING BRANCH
    def filled = PREPROCESS_IMAGE(tiff_ch)
    def mask = CELLPOSE_SEGMENT(filled)
    def roi = AI_ROI_CROP(filled, mask)
    
    // scRNA-SEQ BRANCH
    def qc = SCRNA_QC(combined_h5_ch)
    def filtered = SCRNA_MAD_FILTER(qc)
    def reduced = SCRNA_DIM_REDUCTION(filtered)
    def cluster = SCRNA_CLUSTER(reduced)
    def annot = SCRNA_ANNOTATE(cluster)
    
    // SPATIAL REFINEMENT
    def refined = SPATIAL_REFINE(annot, roi.coords)
    
    // INTEGRATION
    def integrated = SPATIAL_INTEGRATION(roi.roi_img, refined)
    
    // VISUALIZATION AND REPORTING
    SCRNA_PLOTS(refined)
    SPATIAL_PLOTS(integrated)
    REPORT(integrated)
}
