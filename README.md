# AWS Spatial Transcriptomics Pipeline

Optimized spatial transcriptomics analysis pipeline for AWS HealthOmics.

## Features

- 🔬 **Image Processing**: Cellpose segmentation and AI-based ROI cropping
- 🧬 **scRNA-seq Analysis**: QC, filtering, dimensionality reduction, clustering, and cell type annotation
- 🗺️ **Spatial Analysis**: Spatial refinement and integration of transcriptomics with imaging data
- 📊 **Visualization**: Automated plotting and reporting
- 🚀 **AWS HealthOmics Ready**: Optimized for AWS Batch with Wave containers

## Quick Start

```bash
nextflow run main.nf \
  --tiff s3://your-bucket/image.tif \
  --h5 s3://your-bucket/data.h5 \
  --outdir s3://your-bucket/results/
```

## Container

Uses optimized Wave container with all dependencies pre-installed:
```
community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c
```

Includes: cellpose, celltypist, scanpy, squidpy, imageio, leidenalg, and more.

## Pipeline Structure

```
IMAGE: tiff → preprocess → cellpose → roi_crop
                                         ↓
scRNA: h5 → qc → filter → dimred → cluster → annotate → spatial_refine
                                                            ↓
                                                      integration → plots → report
```

## Requirements

- AWS Batch compute environment
- S3 bucket for input/output
- Nextflow 21.04+
- Wave enabled

## Configuration

Edit `nextflow.config` to customize:
- Input/output S3 paths
- AWS region
- Resource allocations per process
- Container specifications

## Processes

1. **PREPROCESS_IMAGE** - Image preprocessing and filling
2. **CELLPOSE_SEGMENT** - Cell segmentation using Cellpose
3. **AI_ROI_CROP** - ROI extraction with AI
4. **SCRNA_QC** - Quality control for scRNA-seq data
5. **SCRNA_MAD_FILTER** - MAD-based filtering
6. **SCRNA_DIM_REDUCTION** - Dimensionality reduction
7. **SCRNA_CLUSTER** - Leiden clustering
8. **SCRNA_ANNOTATE** - Cell type annotation with Celltypist
9. **SPATIAL_REFINE** - Spatial refinement of annotations
10. **SPATIAL_INTEGRATION** - Integration of spatial and transcriptomic data
11. **SCRNA_PLOTS** - Generate scRNA-seq visualizations
12. **SPATIAL_PLOTS** - Generate spatial visualizations
13. **REPORT** - Generate final report

## AWS HealthOmics Optimization

This pipeline is optimized for AWS HealthOmics with:
- ✅ Wave container integration
- ✅ Process-specific resource allocation
- ✅ S3 input/output handling
- ✅ AWS Batch executor configuration
- ✅ Proper DSL2 syntax

## Author

jackdon2896-bit

## License

MIT
