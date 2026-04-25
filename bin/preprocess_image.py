import sys
import numpy as np
import tifffile as tiff
import cv2

input_path = sys.argv[1]
output_path = sys.argv[2]

print("Reading large TIFF safely...")
img = tiff.imread(input_path)

# Normalize if needed
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

# Save safely
tiff.imwrite(output_path, filled)

print("Saved:", output_path)
