import sys, scanpy as sc, numpy as np
adata = sc.read(sys.argv[1])

counts = adata.obs['n_genes_by_counts']
med = np.median(counts)
mad = np.median(np.abs(counts-med))

adata = adata[(counts > med-3*mad) & (counts < med+3*mad)]
adata.write(sys.argv[2])