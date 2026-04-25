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
    
    # ✅ FIX: make gene names unique
    adata.var_names_make_unique()
    
    # Add metadata
    adata.obs['sample'] = '${h5_file.baseName}'
    
    # Optional: ensure obs names are unique too (safe)
    adata.obs_names_make_unique()
    
    # Write as H5AD
    output_file = "converted_${h5_file.baseName}.h5ad"
    adata.write(output_file)
    
    print(f"Successfully converted ${h5_file} to {output_file}")
    print(f"Shape: {adata.shape}")
    
except Exception as e:
    print(f"Error converting ${h5_file}: {str(e)}")
    sys.exit(1)
EOF
    """
}
