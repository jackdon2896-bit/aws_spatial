nextflow.enable.dsl = 2

params.tiff = ""
params.h5 = ""
params.outdir = ""

process {
    container = '644685128986.dkr.ecr.us-east-1.amazonaws.com/seqera/container-spatial:latest'
}

/**********************************
 IMAGE PROCESSING (SAFE)
**********************************/
process PREPROCESS_IMAGE {
    publishDir "${params.outdir}/preprocessed", mode: 'copy'

    cpus 4
    memory '16 GB'

    input:
    path tiff

    output:
    path "filled.tif"

    script:
    """
    python ${projectDir}/bin/preprocess_image.py ${tiff} filled.tif
    """
}

/**********************************
 SEGMENTATION
**********************************/
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

/**********************************
 ROI
**********************************/
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

/**********************************
 H5 → H5AD
**********************************/
process H5_TO_H5AD {
    publishDir "${params.outdir}/converted", mode: 'copy'

    input:
    path h5_file

    output:
    path "converted_${h5_file.baseName}.h5ad", emit: h5ad

    script:
    """
    python - <<EOF
import scanpy as sc
import sys

try:
    print("Reading:", "${h5_file}")
    adata = sc.read_10x_h5("${h5_file}")

    adata.var_names_make_unique()
    adata.obs_names_make_unique()

    adata.obs['sample'] = "${h5_file.baseName}"

    adata.write("converted_${h5_file.baseName}.h5ad")

    print("Done:", adata.shape)

except Exception as e:
    print("ERROR:", str(e))
    sys.exit(1)
EOF
    """
}

/**********************************
 scRNA PIPELINE
**********************************/
process SCRNA_QC {
    publishDir "${params.outdir}/qc", mode: 'copy'

    input:
    path h5ad

    output:
    path "qc.h5ad"

    script:
    """
    python ${projectDir}/bin/qc.py ${h5ad}
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

/**********************************
 SPATIAL
**********************************/
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

/**********************************
 OUTPUTS
**********************************/
process SCRNA_PLOTS {
    publishDir "${params.outdir}/plots", mode: 'copy'

    input:
    path refined

    output:
    path "*.png"

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
    path "*.png"

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

/**********************************
 WORKFLOW
**********************************/
workflow {

    // SAFE S3 INPUT
    def tiff_ch = Channel.fromPath(params.tiff, checkIfExists: true)
    def h5_ch   = Channel.fromPath(params.h5, checkIfExists: true)

    // convert H5 → H5AD
    def h5ad = H5_TO_H5AD(h5_ch).h5ad

    // IMAGE
    def filled = PREPROCESS_IMAGE(tiff_ch)
    def mask   = CELLPOSE_SEGMENT(filled)
    def roi    = AI_ROI_CROP(filled, mask)

    // RNA
    def qc        = SCRNA_QC(h5ad)
    def filtered  = SCRNA_MAD_FILTER(qc)
    def reduced   = SCRNA_DIM_REDUCTION(filtered)
    def cluster   = SCRNA_CLUSTER(reduced)
    def annot     = SCRNA_ANNOTATE(cluster)

    // SPATIAL
    def refined    = SPATIAL_REFINE(annot, roi.coords)
    def integrated = SPATIAL_INTEGRATION(roi.roi_img, refined)

    // OUTPUT
    SCRNA_PLOTS(refined)
    SPATIAL_PLOTS(integrated)
    REPORT(integrated)
}
