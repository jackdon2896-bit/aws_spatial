nextflow.enable.dsl=2

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
    def tiff_ch = channel.fromPath(params.tiff)
    def h5_ch   = channel.fromPath(params.h5)

    // IMAGE PROCESSING BRANCH
    def filled = PREPROCESS_IMAGE(tiff_ch)
    def mask   = CELLPOSE_SEGMENT(filled)
    def roi    = AI_ROI_CROP(filled, mask)

    // scRNA-SEQ BRANCH
    def qc       = SCRNA_QC(h5_ch)
    def filtered = SCRNA_MAD_FILTER(qc)
    def reduced  = SCRNA_DIM_REDUCTION(filtered)
    def cluster  = SCRNA_CLUSTER(reduced)
    def annot    = SCRNA_ANNOTATE(cluster)

    // SPATIAL REFINEMENT
    def refined  = SPATIAL_REFINE(annot, roi.coords)

    // INTEGRATION
    def integrated = SPATIAL_INTEGRATION(roi.roi_img, refined)

    // VISUALIZATION AND REPORTING
    SCRNA_PLOTS(refined)
    SPATIAL_PLOTS(integrated)
    REPORT(integrated)
}