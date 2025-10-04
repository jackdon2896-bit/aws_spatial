import sys, scanpy as sc
import os

input_file = sys.argv[1]
file_ext = os.path.splitext(input_file)[1].lower()

# Handle different input formats
if file_ext == '.h5ad':
    adata = sc.read_h5ad(input_file)
elif file_ext == '.h5':
    adata = sc.read_10x_h5(input_file)
else:
    raise ValueError(f"Unsupported file format: {file_ext}")

# Basic QC filtering
sc.pp.filter_cells(adata, min_genes=200)
sc.pp.filter_genes(adata, min_cells=3)

# Calculate QC metrics
adata.var['mt'] = adata.var_names.str.startswith('MT-')
sc.pp.calculate_qc_metrics(adata, percent_top=None, log1p=False, inplace=True)

adata.write("qc.h5ad")