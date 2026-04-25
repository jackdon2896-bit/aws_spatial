import sys
import numpy as np
import tifffile as tiff
import cv2

input_path = sys.argv[1]
output_path = sys.argv[2]

# Read large TIFF safely
img = tiff.imread(input_path)

# Convert to uint8 if needed (OpenCV requirement)
if img.dtype != np.uint8:
    img = cv2.normalize(img, None, 0, 255, cv2.NORM_MINMAX)
    img = img.astype(np.uint8)

# If image is multi-channel, convert to grayscale
if len(img.shape) == 3:
    img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# Create mask (same logic as your original)
mask = (img < 10).astype(np.uint8)

# Apply inpainting
filled = cv2.inpaint(img, mask, 3, cv2.INPAINT_TELEA)

# Save using tifffile (handles large output)
tiff.imwrite(output_path, filled)
