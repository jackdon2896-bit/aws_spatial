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
import sys

try:
    print("Reading 10x H5 file: ${h5_file}")
    
    adata = sc.read_10x_h5("${h5_file}")
    
    # Fix duplicate genes
    adata.var_names_make_unique()
    
    # Fix duplicate cells (safe)
    adata.obs_names_make_unique()
    
    adata.obs['sample'] = '${h5_file.baseName}'
    
    output_file = "converted_${h5_file.baseName}.h5ad"
    adata.write(output_file)
    
    print("SUCCESS:", output_file)
    print("Shape:", adata.shape)

except Exception as e:
    print("ERROR:", str(e))
    sys.exit(1)
EOF
    """
}
