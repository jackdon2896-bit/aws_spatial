import sys
import tifffile as tiff
import numpy as np
import cv2

input_path = sys.argv[1]
output_path = sys.argv[2]

print("Reading large TIFF safely...")

with tiff.TiffFile(input_path) as tif:
    image = tif.asarray(out='memmap')  # memory safe

# Normalize
image = image.astype(np.float32)
image = (image - image.min()) / (image.max() - image.min())
image = (image * 255).astype(np.uint8)

# Grayscale
if len(image.shape) == 3:
    image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

# Mask
mask = (image < 10).astype(np.uint8)

# Inpaint
filled = cv2.inpaint(image, mask, 3, cv2.INPAINT_TELEA)

# Save
tiff.imwrite(output_path, filled)

print("Saved:", output_path)
