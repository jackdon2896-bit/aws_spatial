# AWS HealthOmics Compatible Container for Spatial Transcriptomics
FROM community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c

# Set working directory
WORKDIR /opt/workflow

# Install system dependencies including SRA Toolkit requirements
RUN apt-get update && apt-get install -y \
    awscli \
    curl \
    wget \
    unzip \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install SRA Toolkit (v3.0.7)
RUN wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/3.0.7/sratoolkit.3.0.7-ubuntu64.tar.gz && \
    tar -xzf sratoolkit.3.0.7-ubuntu64.tar.gz && \
    mv sratoolkit.3.0.7-ubuntu64/bin/* /usr/local/bin/ && \
    rm -rf sratoolkit.3.0.7-ubuntu64*

# Install Python packages
# Note: We use compatible versions of boto3/aiobotocore to prevent resolution errors
RUN pip install --no-cache-dir \
    scanpy \
    squidpy \
    anndata \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    boto3==1.28.64 \
    aiobotocore==2.7.0 \
    s3fs==2023.9.2 \
    fsspec==2023.9.2

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
