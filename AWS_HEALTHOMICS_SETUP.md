# AWS HealthOmics Workflow Setup Guide

This guide explains how to run the AWS Spatial Transcriptomics pipeline on AWS HealthOmics with the Wave container from Seqera.

## 📦 Container Information

**Wave Container URI:**
```
community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c
```

**Included Tools:**
- **Cellpose** - Cell segmentation from microscopy images
- **CellTypist** - Automated cell type annotation
- **imageio** - Image I/O for TIFF processing
- **leidenalg** - Leiden algorithm for clustering

---

## 🚀 Quick Start

### Prerequisites
1. AWS Account with HealthOmics access
2. AWS CLI installed and configured
3. S3 bucket for input data and outputs
4. IAM role with necessary permissions

### Step 1: Push Container to AWS ECR

The Wave container needs to be available in AWS ECR for HealthOmics to use it.

```bash
# 1. Authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.us-east-1.amazonaws.com

# 2. Create ECR repository
aws ecr create-repository \
  --repository-name spatial-transcriptomics \
  --region us-east-1

# 3. Pull the Wave container
docker pull community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c

# 4. Tag for ECR
docker tag \
  community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c \
  <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/spatial-transcriptomics:v1.0.0

# 5. Push to ECR
docker push <your-account-id>.dkr.ecr.us-east-1.amazonaws.com/spatial-transcriptomics:v1.0.0
```

**Your ECR Container URI will be:**
```
<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/spatial-transcriptomics:v1.0.0
```

Save this URI - you'll need it for the workflow configuration!

---

## 📂 Preparing Input Files in S3

The pipeline requires **3 input files** uploaded to S3:

### Required Input Files

1. **TIFF Image File** (`*.tif` or `*.tiff`)
   - Microscopy image for cell segmentation
   - Typically 2D or 3D fluorescence microscopy image

2. **H5 Data File** (`*.h5` or `*.h5ad`)
   - Gene expression data in HDF5 format
   - Can be AnnData format (.h5ad) or custom H5

3. **Marker Genes File** (`*.csv`)
   - Cell type marker genes for annotation
   - CSV format with cell types and their markers

### S3 Folder Structure

Create the following structure in your S3 bucket:

```
s3://your-bucket-name/
├── spatial-workflow/
│   ├── inputs/
│   │   ├── sample.tif              # TIFF image file
│   │   ├── sample.h5               # H5 expression data
│   │   └── markers.csv             # Marker genes file
│   ├── outputs/                    # Results will be saved here
│   └── work/                       # Nextflow work directory
```

### Upload Files to S3

```bash
# Set your bucket name
BUCKET_NAME="your-bucket-name"
PREFIX="spatial-workflow"

# Upload TIFF image
aws s3 cp /path/to/your/image.tif \
  s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.tif

# Upload H5 data
aws s3 cp /path/to/your/data.h5 \
  s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.h5

# Upload marker genes CSV
aws s3 cp /path/to/your/markers.csv \
  s3://${BUCKET_NAME}/${PREFIX}/inputs/markers.csv

# Verify uploads
aws s3 ls s3://${BUCKET_NAME}/${PREFIX}/inputs/
```

### Example Marker Genes CSV Format

Create a file named `markers.csv` with the following structure:

```csv
cell_type,gene_name,gene_id
T_cell,CD3D,ENSG00000167286
T_cell,CD3E,ENSG00000198851
T_cell,CD4,ENSG00000010610
B_cell,CD19,ENSG00000177455
B_cell,MS4A1,ENSG00000156738
NK_cell,NCAM1,ENSG00000149294
NK_cell,NKG7,ENSG00000105374
Macrophage,CD68,ENSG00000129226
Macrophage,CD163,ENSG00000177575
Fibroblast,COL1A1,ENSG00000108821
Fibroblast,COL1A2,ENSG00000164692
```

Upload this file:
```bash
aws s3 cp markers.csv s3://${BUCKET_NAME}/${PREFIX}/inputs/markers.csv
```

---

## ⚙️ AWS HealthOmics Workflow Configuration

### Step 2: Create HealthOmics Workflow

1. **Navigate to AWS HealthOmics Console**
   - Go to AWS Console → HealthOmics → Workflows

2. **Create New Workflow**
   - Click "Create workflow"
   - Name: `spatial-transcriptomics-pipeline`
   - Engine: Nextflow
   - Source: Upload from local or GitHub

3. **Configure Workflow Parameters**

Create a workflow definition file `workflow-definition.json`:

```json
{
  "name": "spatial-transcriptomics-pipeline",
  "description": "Spatial transcriptomics analysis with Wave containers",
  "engine": "NEXTFLOW",
  "main": "main.nf",
  "parameterTemplate": {
    "tiff": {
      "description": "S3 path to TIFF image file",
      "optional": false
    },
    "h5": {
      "description": "S3 path to H5 data file",
      "optional": false
    },
    "markers": {
      "description": "S3 path to marker genes CSV",
      "optional": false
    },
    "outdir": {
      "description": "S3 output directory",
      "optional": false
    },
    "cellpose_model": {
      "description": "Cellpose model type",
      "optional": true,
      "default": "cyto2"
    },
    "cellpose_diameter": {
      "description": "Expected cell diameter",
      "optional": true,
      "default": 30
    },
    "cluster_resolution": {
      "description": "Leiden clustering resolution",
      "optional": true,
      "default": 1.0
    }
  }
}
```

### Step 3: Update nextflow.config for ECR

Update your `nextflow.config` to use your ECR container:

```groovy
process {
    // Use your ECR container URI
    container = '<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/spatial-transcriptomics:v1.0.0'
}

profiles {
    awshealthomics {
        process {
            container = '<your-account-id>.dkr.ecr.us-east-1.amazonaws.com/spatial-transcriptomics:v1.0.0'
        }
        
        aws {
            region = 'us-east-1'  // Your region
        }
    }
}
```

---

## 🏃 Running the Workflow

### Method 1: AWS HealthOmics Console

1. **Go to HealthOmics Console → Workflows → Your Workflow**

2. **Click "Start Run"**

3. **Configure Run Parameters:**
   ```
   Name: spatial-analysis-run-1
   
   Parameters:
   - tiff: s3://your-bucket-name/spatial-workflow/inputs/sample.tif
   - h5: s3://your-bucket-name/spatial-workflow/inputs/sample.h5
   - markers: s3://your-bucket-name/spatial-workflow/inputs/markers.csv
   - outdir: s3://your-bucket-name/spatial-workflow/outputs
   ```

4. **Select IAM Role** with permissions:
   - S3 read/write access
   - ECR image pull
   - HealthOmics execution

5. **Click "Start Run"**

### Method 2: AWS CLI

```bash
# Set variables
WORKFLOW_ID="<your-workflow-id>"
BUCKET_NAME="your-bucket-name"
PREFIX="spatial-workflow"
ROLE_ARN="arn:aws:iam::<account-id>:role/HealthOmicsWorkflowRole"

# Create parameters file
cat > run-parameters.json << EOF
{
  "tiff": "s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.tif",
  "h5": "s3://${BUCKET_NAME}/${PREFIX}/inputs/sample.h5",
  "markers": "s3://${BUCKET_NAME}/${PREFIX}/inputs/markers.csv",
  "outdir": "s3://${BUCKET_NAME}/${PREFIX}/outputs"
}
EOF

# Start workflow run
aws omics start-run \
  --workflow-id ${WORKFLOW_ID} \
  --role-arn ${ROLE_ARN} \
  --name "spatial-analysis-$(date +%Y%m%d-%H%M%S)" \
  --parameters file://run-parameters.json \
  --output-uri s3://${BUCKET_NAME}/${PREFIX}/outputs \
  --region us-east-1

# Get run ID from output
RUN_ID="<run-id-from-output>"

# Monitor run status
aws omics get-run \
  --id ${RUN_ID} \
  --region us-east-1
```

### Method 3: Using Seqera Platform

If you're using Seqera Platform with AWS integration:

1. **Add Pipeline in Seqera**
   - URL: `https://github.com/jackdon2896-bit/aws_spatial.git`
   - Compute Environment: AWS Batch (configured for your AWS account)

2. **Launch Workflow**
   ```
   Parameters:
   - tiff: s3://your-bucket-name/spatial-workflow/inputs/sample.tif
   - h5: s3://your-bucket-name/spatial-workflow/inputs/sample.h5
   - markers: s3://your-bucket-name/spatial-workflow/inputs/markers.csv
   - outdir: s3://your-bucket-name/spatial-workflow/outputs
   
   Profile: awshealthomics
   Work Directory: s3://your-bucket-name/spatial-workflow/work
   ```

3. **Enable Wave**
   - Check "Enable Wave containers"
   - The Wave container will be automatically pulled

---

## 📊 Expected Output Structure

After successful completion, your S3 bucket will contain:

```
s3://your-bucket-name/spatial-workflow/outputs/
├── segmentation/
│   ├── segmentation_masks.npy
│   ├── segmentation_flows.tif
│   └── segmentation_stats.csv
├── expression/
│   ├── expression_matrix.csv
│   └── cell_metadata.csv
├── clustering/
│   ├── clusters.csv
│   ├── umap_coordinates.csv
│   └── cluster_markers.csv
├── annotation/
│   ├── cell_types.csv
│   └── annotation_scores.csv
├── timeline.html
├── report.html
├── trace.txt
└── dag.html
```

### Download Results

```bash
# Download all results
aws s3 sync \
  s3://${BUCKET_NAME}/${PREFIX}/outputs \
  ./results/

# Download specific output
aws s3 cp \
  s3://${BUCKET_NAME}/${PREFIX}/outputs/annotation/cell_types.csv \
  ./cell_types.csv
```

---

## 🔍 Monitoring and Troubleshooting

### Check Run Status

```bash
# List all runs
aws omics list-runs --region us-east-1

# Get specific run details
aws omics get-run --id <run-id> --region us-east-1

# Get run tasks
aws omics list-run-tasks --id <run-id> --region us-east-1
```

### View Logs

```bash
# Run logs are in CloudWatch Logs
# Log group: /aws/omics/workflow/<workflow-id>

# View logs
aws logs tail /aws/omics/workflow/<workflow-id> --follow --region us-east-1
```

### Common Issues

1. **Container Pull Errors**
   - Verify ECR repository exists
   - Check IAM role has ECR permissions
   - Ensure container was pushed successfully

2. **S3 Access Denied**
   - Verify IAM role has S3 permissions
   - Check bucket policy allows HealthOmics access
   - Ensure files exist in specified paths

3. **Out of Memory Errors**
   - Increase memory in process configuration
   - Check input file sizes
   - Consider downsampling large images

4. **Workflow Fails to Start**
   - Verify all 3 input files exist in S3
   - Check parameter JSON syntax
   - Ensure IAM role ARN is correct

---

## 💰 Cost Estimation

Approximate costs for AWS HealthOmics workflow:

- **Compute**: ~$0.04-0.08 per vCPU hour
- **Storage**: ~$0.023 per GB/month (S3 Standard)
- **Data Transfer**: Free within same region

**Example run costs:**
- Small dataset (< 1GB): ~$1-3
- Medium dataset (1-10GB): ~$5-15
- Large dataset (>10GB): ~$20-50

---

## 🔐 IAM Role Requirements

Create an IAM role with the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name/*",
        "arn:aws:s3:::your-bucket-name"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Resource": "arn:aws:ecr:*:*:repository/spatial-transcriptomics"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "omics:*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 📚 Additional Resources

- [AWS HealthOmics Documentation](https://docs.aws.amazon.com/omics/)
- [Nextflow on AWS](https://www.nextflow.io/docs/latest/aws.html)
- [Wave Containers](https://seqera.io/wave/)
- [Cellpose Documentation](https://cellpose.readthedocs.io/)

---

## 🆘 Support

For issues specific to:
- **AWS HealthOmics**: AWS Support
- **Wave Containers**: Seqera Support
- **Pipeline Code**: GitHub Issues at jackdon2896-bit/aws_spatial

---

**Ready to run your spatial transcriptomics analysis on AWS HealthOmics! 🚀**
