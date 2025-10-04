import scanpy as sc, matplotlib.pyplot as plt, sys

adata = sc.read(sys.argv[1])

sc.pl.umap(adata, color='cell_type', show=False)
plt.savefig("celltype.png")

sc.pl.umap(adata, color='cell_type_refined', show=False)
plt.savefig("refined.png")

sc.pl.rank_genes_groups_heatmap(adata, groupby='cell_type', show=False)
plt.savefig("heatmap.png")