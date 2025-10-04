# 📂 S3 Input Files Preparation Guide

Complete guide for preparing and uploading the **3 required input files** to S3 for the AWS Spatial Transcriptomics pipeline.

---

## 📋 Overview

The pipeline requires **exactly 3 input files**:

| # | File Type | Extension | Purpose | Typical Size |
|---|-----------|-----------|---------|--------------|
| 1 | TIFF Image | `.tif`, `.tiff` | Microscopy image for segmentation | 50 MB - 5 GB |
| 2 | H5 Data | `.h5`, `.h5ad` | Gene expression matrix | 100 MB - 10 GB |
| 3 | Markers CSV | `.csv` | Cell type marker genes | < 1 MB |

---

## 🗂️ Recommended S3 Folder Structure

```
s3://your-bucket-name/
└── spatial-workflow/
    ├── inputs/                          ← Upload your 3 files here
    │   ├── sample.tif                   ← File #1: TIFF image
    │   ├── sample.h5                    ← File #2: H5 expression data
    │   └── markers.csv                  ← File #3: Marker genes
    │
    ├── outputs/                         ← Pipeline outputs go here
    │   ├── segmentation/
    │   ├── expression/
    │   ├── clustering/
    │   └── annotation/
    │
    └── work/                            ← Nextflow working directory
```

---

## 📥 File #1: TIFF Image File

### Description
Microscopy image file containing spatial information of cells/tissue for segmentation.

### Specifications
- **Format**: TIFF (.tif or .tiff)
- **Dimensions**: 2D or 3D
- **Channels**: Single or multi-channel (RGB, grayscale, or fluorescence)
- **Bit depth**: 8-bit, 16-bit, or 32-bit
- **Typical size**: 50 MB - 5 GB

### Where to Get It
- Microscopy imaging systems (Zeiss, Leica, Nikon, etc.)
- Spatial transcriptomics platforms (Visium, MERFISH, seqFISH)
- Public datasets (Human Protein Atlas, BioImage Archive)

### Example: Create Test TIFF (Python)

```python
import numpy as np
import imageio.v2 as imageio

# Create a synthetic microscopy image (for testing)
height, width = 2048, 2048
image = np.random.randint(0, 255, (height, width, 3), dtype=np.uint8)

# Add some "cells" (bright spots)
for i in range(100):
    y, x = np.random.randint(50, height-50), np.random.randint(50, width-50)
    radius = np.random.randint(10, 30)
    yy, xx = np.ogrid[-radius:radius, -radius:radius]
    circle = xx**2 + yy**2 <= radius**2
    image[y-radius:y+radius, x-radius:x+radius][circle] = 255

# Save as TIFF
imageio.imwrite('sample.tif', image)
print("Created sample.tif")
```

### Upload to S3

```bash
# Upload TIFF file
aws s3 cp sample.tif s3://your-bucket-name/spatial-workflow/inputs/sample.tif

# Verify upload
aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/sample.tif
```

### Verify File

```bash
# Check file size
aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/ --human-readable

# Download to verify
aws s3 cp s3://your-bucket-name/spatial-workflow/inputs/sample.tif ./test_sample.tif
```

---

## 📊 File #2: H5 Expression Data File

### Description
HDF5 file containing gene expression data, typically from spatial transcriptomics experiments.

### Specifications
- **Format**: HDF5 (.h5) or AnnData (.h5ad)
- **Structure**: 
  - Expression matrix (cells × genes)
  - Optional: Gene names, cell metadata, spatial coordinates
- **Typical size**: 100 MB - 10 GB

### Where to Get It
- Spatial transcriptomics platforms (10x Visium, Slide-seq)
- Single-cell RNA-seq experiments
- Public datasets (GEO, Single Cell Portal)

### Expected H5 Structure

```
/matrix              # Main expression matrix (n_cells × n_genes)
/genes               # Gene names/IDs
/barcodes            # Cell barcodes
/spatial_coords      # Optional: X,Y coordinates
```

### Example: Create Test H5 File (Python)

```python
import h5py
import numpy as np

# Parameters
n_cells = 1000
n_genes = 500

# Create expression matrix (sparse-like)
expression = np.random.poisson(5, (n_cells, n_genes)).astype(float)
expression[expression < 2] = 0  # Make it sparse

# Gene names
genes = [f"GENE{i:04d}" for i in range(n_genes)]

# Cell barcodes
barcodes = [f"CELL{i:05d}" for i in range(n_cells)]

# Create H5 file
with h5py.File('sample.h5', 'w') as f:
    # Expression matrix
    f.create_dataset('matrix', data=expression, compression='gzip')
    
    # Gene information
    f.create_dataset('genes', 
                     data=np.array(genes, dtype='S20'))
    
    # Cell barcodes
    f.create_dataset('barcodes', 
                     data=np.array(barcodes, dtype='S20'))
    
    # Optional: Spatial coordinates
    spatial = np.random.rand(n_cells, 2) * 1000
    f.create_dataset('spatial_coords', data=spatial)
    
    # Metadata
    f.attrs['n_cells'] = n_cells
    f.attrs['n_genes'] = n_genes
    f.attrs['description'] = 'Spatial transcriptomics data'

print("Created sample.h5")
print(f"Size: {n_cells} cells × {n_genes} genes")
```

### Alternative: Convert from AnnData

```python
import anndata as ad
import scanpy as sc

# If you have an AnnData object
adata = ad.read_h5ad('your_data.h5ad')

# Save as H5
adata.write_h5ad('sample.h5')
```

### Upload to S3

```bash
# Upload H5 file
aws s3 cp sample.h5 s3://your-bucket-name/spatial-workflow/inputs/sample.h5

# Verify upload
aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/sample.h5
```

### Inspect H5 File

```python
import h5py

# Check structure
with h5py.File('sample.h5', 'r') as f:
    print("Keys:", list(f.keys()))
    print("Shape:", f['matrix'].shape)
    print("Attributes:", dict(f.attrs))
```

---

## 🧬 File #3: Marker Genes CSV

### Description
CSV file containing cell type marker genes used for automated cell type annotation.

### Specifications
- **Format**: CSV (Comma-Separated Values)
- **Required columns**: `cell_type`, `gene_name`
- **Optional columns**: `gene_id`, `weight`, `confidence`
- **Typical size**: < 1 MB

### CSV Format

```csv
cell_type,gene_name,gene_id
T_cell,CD3D,ENSG00000167286
T_cell,CD3E,ENSG00000198851
T_cell,CD4,ENSG00000010610
T_cell,CD8A,ENSG00000153563
B_cell,CD19,ENSG00000177455
B_cell,MS4A1,ENSG00000156738
B_cell,CD79A,ENSG00000105369
NK_cell,NCAM1,ENSG00000149294
NK_cell,NKG7,ENSG00000105374
NK_cell,KLRD1,ENSG00000134539
Macrophage,CD68,ENSG00000129226
Macrophage,CD163,ENSG00000177575
Macrophage,CSF1R,ENSG00000182578
Monocyte,CD14,ENSG00000170458
Monocyte,FCGR3A,ENSG00000203747
Dendritic_cell,ITGAX,ENSG00000173472
Dendritic_cell,CLEC9A,ENSG00000197594
Fibroblast,COL1A1,ENSG00000108821
Fibroblast,COL1A2,ENSG00000164692
Fibroblast,DCN,ENSG00000011465
Endothelial,PECAM1,ENSG00000261371
Endothelial,VWF,ENSG00000110799
Endothelial,CD34,ENSG00000174059
Epithelial,EPCAM,ENSG00000119888
Epithelial,KRT18,ENSG00000111057
Epithelial,KRT19,ENSG00000171345
```

### Example: Create Marker File (Python)

```python
import csv

# Define cell type markers
markers = {
    'T_cell': ['CD3D', 'CD3E', 'CD4', 'CD8A', 'IL7R'],
    'B_cell': ['CD19', 'MS4A1', 'CD79A', 'CD79B'],
    'NK_cell': ['NCAM1', 'NKG7', 'KLRD1', 'GNLY'],
    'Macrophage': ['CD68', 'CD163', 'CSF1R', 'C1QA'],
    'Monocyte': ['CD14', 'FCGR3A', 'S100A8', 'S100A9'],
    'Dendritic_cell': ['ITGAX', 'CLEC9A', 'FCER1A'],
    'Fibroblast': ['COL1A1', 'COL1A2', 'DCN', 'LUM'],
    'Endothelial': ['PECAM1', 'VWF', 'CD34', 'CLDN5'],
    'Epithelial': ['EPCAM', 'KRT18', 'KRT19', 'CDH1']
}

# Write to CSV
with open('markers.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['cell_type', 'gene_name', 'gene_id'])
    
    for cell_type, genes in markers.items():
        for gene in genes:
            # Gene ID is optional - can be left empty or use placeholder
            gene_id = f"ENSG_{gene}"
            writer.writerow([cell_type, gene, gene_id])

print("Created markers.csv with", sum(len(v) for v in markers.values()), "markers")
```

### Example: Tissue-Specific Markers

**Brain Tissue:**
```csv
cell_type,gene_name,gene_id
Neuron,MAP2,ENSG00000078018
Neuron,RBFOX3,ENSG00000167552
Neuron,SYP,ENSG00000102003
Astrocyte,GFAP,ENSG00000131095
Astrocyte,AQP4,ENSG00000171885
Oligodendrocyte,MBP,ENSG00000197971
Oligodendrocyte,MOG,ENSG00000204655
Microglia,CX3CR1,ENSG00000168329
Microglia,P2RY12,ENSG00000169860
```

**Tumor Tissue:**
```csv
cell_type,gene_name,gene_id
Tumor_cell,MKI67,ENSG00000148773
Tumor_cell,TOP2A,ENSG00000131747
CAF,ACTA2,ENSG00000107796
CAF,FAP,ENSG00000078098
TAM,CD68,ENSG00000129226
TAM,CD163,ENSG00000177575
```

### Upload to S3

```bash
# Upload markers file
aws s3 cp markers.csv s3://your-bucket-name/spatial-workflow/inputs/markers.csv

# Verify upload
aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/markers.csv
```

### Validate Markers File

```bash
# Download and check
aws s3 cp s3://your-bucket-name/spatial-workflow/inputs/markers.csv ./check_markers.csv

# Count markers per cell type
cut -d',' -f1 check_markers.csv | sort | uniq -c
```

---

## 🚀 Complete Upload Workflow

### Step-by-Step Upload Process

```bash
# 1. Set your S3 bucket name
BUCKET_NAME="your-bucket-name"
PREFIX="spatial-workflow"

# 2. Create S3 folder structure
aws s3api put-object \
  --bucket ${BUCKET_NAME} \
  --key ${PREFIX}/inputs/

aws s3api put-object \
  --bucket ${BUCKET_NAME} \
  --key ${PREFIX}/outputs/

aws s3api put-object \
  --bucket ${BUCKET_NAME} \
  --key ${PREFIX}/work/

# 3. Upload all 3 input files
echo "Uploading TIFF image..."
aws s3 cp sample.tif \
  s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.tif \
  --storage-class STANDARD

echo "Uploading H5 data..."
aws s3 cp sample.h5 \
  s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.h5 \
  --storage-class STANDARD

echo "Uploading markers CSV..."
aws s3 cp markers.csv \
  s3://${BUCKET_NAME}/${PREFIX}/inputs/markers.csv \
  --storage-class STANDARD

# 4. Verify all uploads
echo "Verifying uploads..."
aws s3 ls s3://${BUCKET_NAME}/${PREFIX}/inputs/ --human-readable --summarize

# 5. Check file count (should be 3)
FILE_COUNT=$(aws s3 ls s3://${BUCKET_NAME}/${PREFIX}/inputs/ | wc -l)
echo "Files uploaded: ${FILE_COUNT}"

if [ $FILE_COUNT -eq 3 ]; then
  echo "✅ All 3 input files uploaded successfully!"
else
  echo "❌ Warning: Expected 3 files, found ${FILE_COUNT}"
fi
```

### Bulk Upload Script

Create a script `upload_to_s3.sh`:

```bash
#!/bin/bash

# Configuration
BUCKET_NAME="${1:-your-bucket-name}"
PREFIX="${2:-spatial-workflow}"
LOCAL_DIR="${3:-.}"

# Validate inputs
if [ -z "$BUCKET_NAME" ]; then
  echo "Usage: $0 <bucket-name> [prefix] [local-dir]"
  exit 1
fi

# Check if required files exist
REQUIRED_FILES=("sample.tif" "sample.h5" "markers.csv")
for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "${LOCAL_DIR}/${file}" ]; then
    echo "❌ Error: ${file} not found in ${LOCAL_DIR}"
    exit 1
  fi
done

echo "📦 Uploading spatial transcriptomics input files..."
echo "   Bucket: s3://${BUCKET_NAME}/${PREFIX}/inputs/"
echo ""

# Upload files with progress
for file in "${REQUIRED_FILES[@]}"; do
  echo "⬆️  Uploading ${file}..."
  aws s3 cp "${LOCAL_DIR}/${file}" \
    "s3://${BUCKET_NAME}/${PREFIX}/inputs/${file}" \
    --storage-class STANDARD
  
  if [ $? -eq 0 ]; then
    echo "   ✅ ${file} uploaded successfully"
  else
    echo "   ❌ Failed to upload ${file}"
    exit 1
  fi
done

echo ""
echo "🎉 All files uploaded successfully!"
echo ""
echo "S3 Paths for pipeline:"
echo "  --tiff s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.tif"
echo "  --h5 s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.h5"
echo "  --markers s3://${BUCKET_NAME}/${PREFIX}/inputs/markers.csv"
echo "  --outdir s3://${BUCKET_NAME}/${PREFIX}/outputs"
```

Make it executable and run:
```bash
chmod +x upload_to_s3.sh
./upload_to_s3.sh your-bucket-name spatial-workflow ./data
```

---

## ✅ Pre-Flight Checklist

Before running the pipeline, verify:

- [ ] **File #1 (TIFF)**: Uploaded to S3
  ```bash
  aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/sample.tif
  ```

- [ ] **File #2 (H5)**: Uploaded to S3
  ```bash
  aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/sample.h5
  ```

- [ ] **File #3 (Markers CSV)**: Uploaded to S3
  ```bash
  aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/markers.csv
  ```

- [ ] **S3 Bucket**: Accessible from AWS HealthOmics
  ```bash
  aws s3 ls s3://your-bucket-name/spatial-workflow/
  ```

- [ ] **IAM Permissions**: Role has S3 read/write access

- [ ] **File Sizes**: Within expected ranges
  ```bash
  aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/ --human-readable
  ```

---

## 📝 Pipeline Launch Command

Once all 3 files are uploaded, use these S3 paths in your pipeline:

```bash
# AWS HealthOmics
aws omics start-run \
  --workflow-id <workflow-id> \
  --role-arn <role-arn> \
  --parameters '{
    "tiff": "s3://your-bucket-name/spatial-workflow/inputs/sample.tif",
    "h5": "s3://your-bucket-name/spatial-workflow/inputs/sample.h5",
    "markers": "s3://your-bucket-name/spatial-workflow/inputs/markers.csv",
    "outdir": "s3://your-bucket-name/spatial-workflow/outputs"
  }'

# Or Nextflow CLI
nextflow run main.nf \
  --tiff s3://your-bucket-name/spatial-workflow/inputs/sample.tif \
  --h5 s3://your-bucket-name/spatial-workflow/inputs/sample.h5 \
  --markers s3://your-bucket-name/spatial-workflow/inputs/markers.csv \
  --outdir s3://your-bucket-name/spatial-workflow/outputs \
  -profile awshealthomics \
  -bucket-dir s3://your-bucket-name/spatial-workflow/work
```

---

## 🔧 Troubleshooting

### Issue: "File not found in S3"
```bash
# Check if file exists
aws s3 ls s3://your-bucket-name/spatial-workflow/inputs/

# Check file path is correct (no extra spaces)
aws s3api head-object \
  --bucket your-bucket-name \
  --key spatial-workflow/inputs/sample.tif
```

### Issue: "Access Denied"
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket your-bucket-name

# Test IAM permissions
aws s3 cp s3://your-bucket-name/spatial-workflow/inputs/sample.tif ./test.tif
```

### Issue: "Large file upload timeout"
```bash
# Use multipart upload for large files
aws s3 cp large_file.tif s3://your-bucket-name/path/ \
  --storage-class STANDARD \
  --metadata-directive REPLACE
```

---

## 📚 Additional Resources

- [AWS S3 Upload Documentation](https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html)
- [H5 File Format](https://portal.hdfgroup.org/display/HDF5/HDF5)
- [Cellpose Image Requirements](https://cellpose.readthedocs.io/)

---

**Your 3 input files are now ready in S3! 🎉**

Proceed to `AWS_HEALTHOMICS_SETUP.md` to run the pipeline.
