import sys, imageio
from cellpose import models

img = imageio.imread(sys.argv[1])
model = models.CellposeModel(pretrained_model='cyto3', gpu=False)

masks, _, _ = model.eval(img, channels=[0,0])

imageio.imwrite(sys.argv[2], (masks>0).astype('uint8')*255)