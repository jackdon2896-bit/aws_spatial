# AWS Spatial Transcriptomics Pipeline

Spatial transcriptomics analysis pipeline optimized for AWS HealthOmics, integrating scRNA-seq data (e.g., GSE200972) with Visium HD spatial imaging data.

## Features

- ✅ **Automated SRA download** from GEO datasets (e.g., GSE200972)
- ✅ **10x Visium HD support** with direct data download
- ✅ **Gene-specific filtering** via configurable parameters
- ✅ **AWS HealthOmics optimized** with AWS Batch, S3, and Wave containers
- ✅ **Complete workflow**: Image processing → scRNA-seq analysis → Spatial integration
- ✅ **Automated reports** with trace, timeline, and analysis plots

## Pipeline Overview

```
┌─────────────────┐        ┌──────────────────┐
│  SRA Download   │   OR   │  Pre-processed   │
│  (GSE200972)    │        │  H5 Data         │
└────────┬────────┘        └────────┬─────────┘
         │                          │
         v                          v
    ┌────────────────────────────────────┐
    │  scRNA-seq Processing              │
    │  QC → Filter → PCA → Cluster       │
    │  → Cell Type Annotation            │
    └────────────┬───────────────────────┘
                 │
    ┌────────────┴─────────────┐
    │  Image Processing        │
    │  TIFF → Preprocess       │
    │  → Cellpose → ROI        │
    └────────────┬─────────────┘
                 │
                 v
    ┌────────────────────────────┐
    │  Spatial Integration       │
    │  Refine → Integrate        │
    │  → Visualize → Report      │
    └────────────────────────────┘
```

## Quick Start

### Option 1: Using SRA Data from GEO (GSE200972)

```bash
nextflow run main.nf \
  -c example_configs/gse200972_config.config
```

### Option 2: Using Pre-processed Data

```bash
nextflow run main.nf \
  --h5 s3://your-bucket/data.h5 \
  --tiff s3://your-bucket/image.tif \
  --outdir s3://your-bucket/results/
```

### Option 3: Download 10x Spatial Data Automatically

```bash
nextflow run main.nf \
  --sra_accessions "SRR18196347,SRR18196348" \
  --spatial_data_url "https://cf.10xgenomics.com/samples/spatial-exp/..." \
  --gene_ids "TP53,EGFR,KRAS" \
  --outdir s3://your-bucket/results/
```

## Configuration Parameters

### Required (choose one set):

**For scRNA-seq data:**
- `--sra_accessions`: Comma-separated SRA accession numbers (e.g., "SRR18196347,SRR18196348")
- OR `--h5`: Path to pre-processed H5/H5AD file (local or S3)

**For spatial imaging:**
- `--spatial_data_url`: URL to download 10x Visium HD data
- OR `--tiff`: Path to TIFF image file (local or S3)

**Output:**
- `--outdir`: S3 bucket path for results (e.g., "s3://your-bucket/results/")

### Optional:

- `--gene_ids`: Comma-separated gene IDs for filtering (e.g., "TP53,EGFR,KRAS,MYC")
- `--aws_region`: AWS region (default: "ap-south-1")

## Example Configurations

See `example_configs/` directory:
- `gse200972_config.config`: Using GSE200972 lung cancer data
- `precomputed_config.config`: Using pre-existing H5 and TIFF files

## Containers

**Main container:**
```
community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c
```
Includes: cellpose, celltypist, scanpy, squidpy, imageio, leidenalg, anndata

**SRA download:**
```
community.wave.seqera.io/library/sra-tools:3.1.1--10efe8a96a5789e6
```

## Output Structure

```
s3://your-bucket/results/
├── sra_download/          # Downloaded SRA files (if using --sra_accessions)
├── counts/                # Gene count matrices
├── spatial_raw/           # Downloaded spatial data
├── preprocessed/          # Pre-processed images
├── segmentation/          # Cell segmentation masks
├── roi/                   # Extracted ROIs and coordinates
├── qc/                    # QC-filtered scRNA data
├── filtered/              # MAD-filtered data
├── dimred/                # Dimensionality reduction results
├── clusters/              # Clustered data
├── annotated/             # Cell type annotations
├── refined/               # Spatially refined annotations
├── integrated/            # Final integrated data
├── plots/                 # scRNA-seq visualizations
├── spatial_plots/         # Spatial visualizations
├── report/                # Final analysis report
├── pipeline_trace.txt     # Execution trace
├── pipeline_timeline.html # Timeline visualization
└── pipeline_report.html   # Nextflow execution report
```

## AWS HealthOmics Setup

1. **IAM Permissions**: Ensure your AWS credentials have permissions for:
   - AWS Batch (submit jobs, describe queues, etc.)
   - S3 (read/write to your buckets)
   - EC2/ECS (for Batch compute)

2. **S3 Buckets**: Create buckets for:
   - Input data (if not using SRA download)
   - Output results

3. **AWS Batch**: Set up compute environment and job queue in your region

4. **Run Pipeline**:
```bash
nextflow run main.nf -c your_config.config -profile awsbatch
```

## Resource Allocation

Process-specific resources optimized for AWS Batch:
- **SRA Download**: 4 CPUs, 8 GB RAM, 6h
- **FASTQ to Counts**: 4 CPUs, 16 GB RAM, 8h
- **Cellpose Segmentation**: 4 CPUs, 16 GB RAM, 4h
- **Cell Type Annotation**: 4 CPUs, 16 GB RAM, 4h
- **Other processes**: 1-4 CPUs, 4-16 GB RAM

## Troubleshooting

### SRA Download Issues
- Ensure network connectivity to NCBI
- Check SRA accession numbers are valid
- Increase time limit if downloads are slow

### Memory Issues
- Increase memory in `nextflow.config` for specific processes
- Use smaller datasets for testing

### S3 Access Issues
- Verify IAM permissions
- Check bucket names and regions
- Ensure credentials are properly configured

## Citation

If using GSE200972 data, please cite:
- Original publication for GSE200972 dataset

For 10x Visium HD lung cancer data:
- 10x Genomics Visium HD dataset

## License

MIT License
