import sys, scanpy as sc
adata = sc.read(sys.argv[1])
sc.tl.leiden(adata, resolution=1.0)
adata.write(sys.argv[2])