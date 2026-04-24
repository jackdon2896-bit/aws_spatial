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
import anndata as ad
import sys

try:
    print("Reading 10x H5 file: ${h5_file}")
    
    # Read 10x H5 file
    adata = sc.read_10x_h5("${h5_file}")
    
    # Make variable names unique (important for 10x data)
    adata.var_names_unique()
    
    # Add basic metadata
    adata.obs['sample'] = '${h5_file.baseName}'
    
    # Write as H5AD
    adata.write("converted_${h5_file.baseName}.h5ad")
    
    print(f"Successfully converted ${h5_file} to H5AD format")
    print(f"Shape: {adata.shape}")
    
except Exception as e:
    print(f"Error converting ${h5_file}: {str(e)}")
    sys.exit(1)
EOF
    """
}
