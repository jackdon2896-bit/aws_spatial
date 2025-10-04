import sys, scanpy as sc, squidpy as sq, imageio

img = imageio.imread(sys.argv[1])
adata = sc.read(sys.argv[2])

adata.uns["spatial"] = {
 "sample":{"images":{"hires":img},
 "scalefactors":{"tissue_hires_scalef":1.0}}
}

sq.gr.spatial_neighbors(adata)
adata.write(sys.argv[3])