# AWS Spatial Transcriptomics Pipeline

Spatial transcriptomics analysis pipeline optimized for AWS HealthOmics with SRA download capability.

## Quick Start

### With existing H5 data:
```bash
nextflow run main.nf \
  --tiff s3://tiffimage/tiffimage/lungstiff.tif \
  --h5 s3://tiffimage/tiffimage/lungsfeaturematrix.h5 \
  --outdir s3://tiffimage/results/
```

### With SRA download:
```bash
nextflow run main.nf \
  --tiff s3://tiffimage/tiffimage/lungstiff.tif \
  --sra_ids "SRR123456,SRR123457" \
  --outdir s3://tiffimage/results/
```

### With both H5 and SRA data:
```bash
nextflow run main.nf \
  --tiff s3://tiffimage/tiffimage/lungstiff.tif \
  --h5 s3://tiffimage/tiffimage/lungsfeaturematrix.h5 \
  --sra_ids "SRR123456,SRR123457" \
  --outdir s3://tiffimage/results/
```

## Pipeline

**SRA Processing** (Optional): SRA IDs → Download → FASTQ → H5AD Conversion  
**Image Processing**: TIFF → Preprocess → Cellpose Segmentation → ROI Extraction  
**scRNA-seq**: H5/H5AD → QC → Filter → Dimensionality Reduction → Cluster → Annotate  
**Spatial Integration**: ROI + Annotations → Spatial Refinement → Integration → Plots → Report

## Parameters

- `--tiff`: Path to TIFF image file (required)
- `--h5`: Path to H5 feature matrix (optional if using SRA)
- `--sra_ids`: Comma-separated list of SRA accession IDs (optional)
- `--outdir`: Output directory for results

## Container

```
community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c
```

Includes: cellpose, celltypist, scanpy, squidpy, imageio, leidenalg, anndata, sra-tools

## New Features

✅ **SRA Download**: Automatically download and process SRA datasets  
✅ **FASTQ to H5AD**: Convert FASTQ files to scanpy-compatible H5AD format  
✅ **Flexible Input**: Support both direct H5 files and SRA accession IDs  
✅ **Enhanced S3**: Optimized S3 integration with intelligent tiering  
✅ **AWS HealthOmics**: Fully compatible with AWS HealthOmics workflows

## Configuration

AWS HealthOmics ready with:
- ✅ Wave & Docker enabled
- ✅ AWS Batch executor (ap-south-1)
- ✅ Process-specific resources (1-4 CPUs, 4-16 GB RAM)
- ✅ S3 input/output support
- ✅ SRA download capability
- ✅ Enhanced S3 optimization

## Usage Examples

### Test with SRA data:
```bash
nextflow run main.nf -c conf/test_sra.config
```

### Production run with real SRA IDs:
```bash
nextflow run main.nf \
  --tiff s3://your-bucket/spatial/image.tif \
  --sra_ids "SRR15440796,SRR15440797" \
  --outdir s3://your-bucket/results/
```
