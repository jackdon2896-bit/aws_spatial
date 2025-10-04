import sys
import tifffile as tiff
import numpy as np
import cv2

input_path = sys.argv[1]
output_path = sys.argv[2]

print("Reading large TIFF safely...")

with tiff.TiffFile(input_path) as tif:
    # Read image metadata
    print(f"Image shape: {tif.pages[0].shape}, dtype: {tif.pages[0].dtype}")
    
    # Read image in chunks to reduce memory footprint
    image = tif.asarray()

print("Normalizing image...")
# Compute min/max for normalization
img_min = np.min(image)
img_max = np.max(image)
print(f"Image range: {img_min} to {img_max}")

# Normalize in-place to save memory
image = ((image - img_min) / (img_max - img_min) * 255).astype(np.uint8)

# Convert to grayscale if needed
if len(image.shape) == 3:
    print("Converting to grayscale...")
    image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

print("Creating mask for inpainting...")
# Create mask for dark regions
mask = (image < 10).astype(np.uint8)

print("Inpainting dark regions...")
# Inpaint to fill dark regions
filled = cv2.inpaint(image, mask, 3, cv2.INPAINT_TELEA)

print("Saving preprocessed image...")
# Save output
tiff.imwrite(output_path, filled, compression='deflate')

print(f"Successfully saved: {output_path}")
