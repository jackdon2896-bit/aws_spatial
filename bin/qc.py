import sys, scanpy as sc
adata = sc.read_10x_h5(sys.argv[1])
sc.pp.filter_cells(adata, min_genes=200)
sc.pp.filter_genes(adata, min_cells=3)
adata.write("qc.h5ad")