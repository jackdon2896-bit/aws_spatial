import sys, scanpy as sc
adata = sc.read(sys.argv[1])

sc.pp.normalize_total(adata)
sc.pp.log1p(adata)
sc.pp.pca(adata)
sc.pp.neighbors(adata)
sc.tl.umap(adata)

adata.write(sys.argv[2])