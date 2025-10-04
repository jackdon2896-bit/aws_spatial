# AWS HealthOmics Setup Guide

This guide walks you through setting up your spatial transcriptomics pipeline for AWS HealthOmics following the 4-step process.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed (for container building)
- AWS HealthOmics service enabled in your region

## Step 1: Upload Container to ECR

### 1.1 Build and Push Container

```bash
# Set your AWS region and repository name
export AWS_REGION="us-east-1"
export ECR_REPOSITORY_NAME="aws-spatial-pipeline"

# Run the ECR setup script
./ecr-setup.sh
```

This will:
- Create an ECR repository
- Build the Docker image with all dependencies
- Push the image to ECR
- Provide you with the ECR URI for use in Step 3

### 1.2 Alternative: Use Wave Container

If you prefer to use the existing Wave container, update `nextflow-healthomics.config`:

```groovy
process {
    container = 'community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c'
}
```

## Step 2: Prepare Workflow Definition

### 2.1 Upload Workflow Files to S3

```bash
# Create S3 bucket for workflow storage
aws s3 mb s3://your-workflow-bucket

# Upload workflow files
aws s3 sync . s3://your-workflow-bucket/aws-spatial-pipeline/ \
    --exclude "*.git*" --exclude "work/*" --exclude "results/*"
```

### 2.2 Update Configuration

Edit `nextflow-healthomics.config` and update:
- ECR container URI (from Step 1)
- AWS region
- Resource limits as needed

## Step 3: Create HealthOmics Workflow

### 3.1 Set Up IAM Role

```bash
# Create IAM role for HealthOmics
aws iam create-role \
    --role-name HealthOmicsWorkflowRole \
    --assume-role-policy-document file://healthomics/iam-role-policy.json

# Attach permissions policy
aws iam put-role-policy \
    --role-name HealthOmicsWorkflowRole \
    --policy-name HealthOmicsWorkflowPolicy \
    --policy-document file://healthomics/iam-permissions-policy.json
```

### 3.2 Create Workflow

```bash
# Set environment variables
export S3_WORKFLOW_BUCKET="your-workflow-bucket"
export ROLE_ARN="arn:aws:iam::YOUR_ACCOUNT_ID:role/HealthOmicsWorkflowRole"

# Run workflow creation script
cd healthomics
./create-workflow.sh
```

This will:
- Create a workflow bundle
- Upload to S3
- Create the HealthOmics workflow
- Update parameter templates with workflow ID

## Step 4: Start Workflow Runs

### 4.1 Update Run Parameters

Edit the parameter files in `healthomics/`:

**For SRA data (`run-parameters-sra.json`):**
```json
{
  "parameters": {
    "tiff": "s3://your-data-bucket/spatial/images/sample.tif",
    "sra_ids": "SRR15440796,SRR15440797",
    "outdir": "s3://your-results-bucket/spatial-analysis-results/"
  }
}
```

**For H5 data (`run-parameters-h5.json`):**
```json
{
  "parameters": {
    "tiff": "s3://your-data-bucket/spatial/images/sample.tif",
    "h5": "s3://your-data-bucket/spatial/matrices/sample.h5",
    "outdir": "s3://your-results-bucket/spatial-analysis-results/"
  }
}
```

### 4.2 Start a Run

```bash
# Set your workflow ID (from Step 3)
export WORKFLOW_ID="your-workflow-id"

# Start run with SRA data
./start-run.sh sra

# Or start run with H5 data
./start-run.sh h5
```

### 4.3 Monitor Runs

```bash
# Get run status
aws omics get-run --id YOUR_RUN_ID

# List all runs
aws omics list-runs

# Get run logs
aws omics get-run --id YOUR_RUN_ID --export taskLogs
```

## Pipeline Features

### Input Options

1. **SRA Download Mode:**
   - Provide `sra_ids` parameter with comma-separated SRA accession IDs
   - Pipeline downloads FASTQ files and converts to H5AD format
   - Suitable for public datasets from NCBI SRA

2. **Direct H5 Mode:**
   - Provide `h5` parameter with S3 path to feature matrix
   - Use existing processed data
   - Faster execution for pre-processed datasets

3. **Hybrid Mode:**
   - Provide both `h5` and `sra_ids` parameters
   - Process multiple datasets simultaneously

### Output Structure

```
s3://your-results-bucket/spatial-analysis-results/
├── sra_downloads/          # Downloaded SRA files (if using SRA)
├── h5ad_converted/         # Converted H5AD files (if using SRA)
├── preprocessed/           # Preprocessed TIFF images
├── segmentation/           # Cell segmentation masks
├── roi/                    # Region of interest extractions
├── qc/                     # Quality control results
├── filtered/               # Filtered data
├── dimred/                 # Dimensionality reduction
├── clusters/               # Clustering results
├── annotated/              # Cell type annotations
├── refined/                # Spatially refined annotations
├── integrated/             # Spatial integration results
├── plots/                  # Visualization plots
├── spatial_plots/          # Spatial visualization plots
└── report/                 # Final analysis report
```

## Troubleshooting

### Common Issues

1. **Container Access Issues:**
   - Ensure ECR permissions are correctly set
   - Verify container URI in configuration

2. **S3 Access Issues:**
   - Check IAM role permissions
   - Verify S3 bucket policies

3. **Resource Limits:**
   - Adjust memory/CPU limits in `nextflow-healthomics.config`
   - Consider using GPU instances for Cellpose segmentation

4. **SRA Download Failures:**
   - Check SRA accession IDs are valid
   - Ensure sufficient storage capacity

### Getting Help

- Check AWS HealthOmics documentation
- Review CloudWatch logs for detailed error messages
- Use AWS Support for service-specific issues

## Cost Optimization

1. **Use Spot Instances:** Configure in HealthOmics for cost savings
2. **Right-size Resources:** Adjust CPU/memory based on data size
3. **Storage Classes:** Use appropriate S3 storage classes for outputs
4. **Run Groups:** Use run groups to manage concurrent executions

## Security Best Practices

1. **Least Privilege:** Use minimal IAM permissions
2. **Encryption:** Enable S3 encryption for sensitive data
3. **VPC:** Consider running in private VPC for sensitive workloads
4. **Audit:** Enable CloudTrail for audit logging