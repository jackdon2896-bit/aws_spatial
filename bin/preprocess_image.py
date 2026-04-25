import sys
import numpy as np
import tifffile as tiff
import cv2

input_path = sys.argv[1]
output_path = sys.argv[2]

print("Reading large TIFF using memory-mapped mode...")

# ✅ IMPORTANT: use memmap (does NOT load full image into RAM)
with tiff.TiffFile(input_path) as tif:
    img = tif.asarray(out='memmap')

# Normalize safely
if img.dtype != np.uint8:
    img = cv2.normalize(img, None, 0, 255, cv2.NORM_MINMAX)
    img = img.astype(np.uint8)

# Convert to grayscale if needed
if len(img.shape) == 3:
    img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# Create mask
mask = (img < 10).astype(np.uint8)

# Inpainting
filled = cv2.inpaint(img, mask, 3, cv2.INPAINT_TELEA)

print("Writing output TIFF...")

# Save using tifffile (handles large files better)
tiff.imwrite(output_path, filled)

print("Saved:", output_path)
