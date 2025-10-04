# AWS Spatial Transcriptomics Pipeline

Spatial transcriptomics analysis pipeline optimized for AWS HealthOmics.

## Quick Start

```bash
nextflow run main.nf \
  --tiff s3://tiffimage/tiffimage/lungstiff.tif \
  --h5 s3://tiffimage/tiffimage/lungsfeaturematrix.h5 \
  --outdir s3://tiffimage/results/
```

## Pipeline

**Image Processing**: TIFF → Preprocess → Cellpose Segmentation → ROI Extraction  
**scRNA-seq**: H5 → QC → Filter → Dimensionality Reduction → Cluster → Annotate  
**Spatial Integration**: ROI + Annotations → Spatial Refinement → Integration → Plots → Report

## Container

```
community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c
```

Includes: cellpose, celltypist, scanpy, squidpy, imageio, leidenalg, anndata

## Configuration

AWS HealthOmics ready with:
- ✅ Wave & Docker enabled
- ✅ AWS Batch executor (ap-south-1)
- ✅ Process-specific resources (1-4 CPUs, 4-16 GB RAM)
- ✅ S3 input/output support
