# AWS HealthOmics Compatible Container for Spatial Transcriptomics Pipeline
# Based on the Wave container but optimized for ECR deployment

FROM community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c

# Set working directory
WORKDIR /opt/workflow

# Install additional dependencies for AWS HealthOmics
RUN apt-get update && apt-get install -y \
    awscli \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install additional Python packages for enhanced functionality
RUN pip install --no-cache-dir \
    boto3==1.34.0 \
    s3fs==2023.12.0 \
    fsspec==2023.12.0 \
    aiobotocore==2.8.0

# Copy workflow scripts
COPY bin/ /opt/workflow/bin/
RUN chmod +x /opt/workflow/bin/*.py

# Set environment variables for AWS HealthOmics
ENV PYTHONPATH="/opt/workflow/bin:${PYTHONPATH}"
ENV PATH="/opt/workflow/bin:${PATH}"

# Create directories for workflow execution
RUN mkdir -p /opt/workflow/work /opt/workflow/results

# Set default command
CMD ["/bin/bash"]