import sys, scanpy as sc, celltypist

adata = sc.read(sys.argv[1])
model = celltypist.models.Model.load_default()

pred = celltypist.annotate(adata, model=model, majority_voting=True)

adata.obs['cell_type'] = pred.predicted_labels
adata.obs['confidence'] = pred.conf_score

adata.write(sys.argv[2]) 