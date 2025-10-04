import sys, scanpy as sc, squidpy as sq, numpy as np

adata = sc.read(sys.argv[1])

if "spatial" not in adata.obsm:
    adata.obsm["spatial"] = np.random.rand(adata.n_obs,2)*1000

sq.gr.spatial_neighbors(adata)

labels = adata.obs['cell_type']
neighbors = adata.obsp['spatial_connectivities']

refined = []

for i in range(adata.n_obs):
    idx = neighbors[i].nonzero()[1]
    if len(idx)==0:
        refined.append(labels[i])
        continue
    neigh = labels.iloc[idx]
    refined.append(neigh.value_counts().idxmax())

adata.obs['cell_type_refined'] = refined
adata.write(sys.argv[2])