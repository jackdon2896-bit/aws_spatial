import sys, tifffile, numpy as np, cv2, pandas as pd

img = tifffile.imread(sys.argv[1])
mask = cv2.imread(sys.argv[2], 0)

coords = np.column_stack(np.where(mask>0))
ymin,xmin = coords.min(axis=0)
ymax,xmax = coords.max(axis=0)

roi = img[ymin:ymax, xmin:xmax]

tifffile.imwrite(sys.argv[3], roi, compression='lzw')

pd.DataFrame([[x,y] for y in range(roi.shape[0]) for x in range(roi.shape[1])],
             columns=['x','y']).to_csv(sys.argv[4], index=False)