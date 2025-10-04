#!/usr/bin/env python3
"""
Cellpose segmentation with memory optimization for large tiles.
"""
import sys
import imageio
import numpy as np
from cellpose import models
import gc

def segment_with_cellpose(input_path, output_path):
    """
    Perform cell segmentation using Cellpose with memory optimization.
    
    Args:
        input_path: Path to input image (preprocessed TIFF or tile)
        output_path: Path to save segmentation mask
    """
    print(f"Loading image: {input_path}", file=sys.stderr)
    img = imageio.imread(input_path)
    
    print(f"Image shape: {img.shape}, dtype: {img.dtype}", file=sys.stderr)
    
    # Handle different image formats
    if img.ndim == 3 and img.shape[2] > 1:
        # Multi-channel image - convert to grayscale
        img = np.mean(img, axis=2).astype(img.dtype)
        print(f"Converted to grayscale: {img.shape}", file=sys.stderr)
    
    # Initialize Cellpose model
    # Note: Set gpu=True if GPU is available for 5-10x speedup
    print("Loading Cellpose model (cyto3)...", file=sys.stderr)
    model = models.CellposeModel(pretrained_model='cyto3', gpu=False)
    
    # Run segmentation
    print("Running segmentation...", file=sys.stderr)
    masks, flows, styles = model.eval(img, channels=[0, 0], diameter=None)
    
    # Clear input image from memory
    del img
    gc.collect()
    
    # Convert mask to binary (255 for cells, 0 for background)
    binary_mask = (masks > 0).astype('uint8') * 255
    
    print(f"Segmentation complete. Found {len(np.unique(masks)) - 1} cells", file=sys.stderr)
    
    # Save output
    imageio.imwrite(output_path, binary_mask)
    print(f"Saved mask to: {output_path}", file=sys.stderr)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: segment_cellpose.py <input_image> <output_mask>", file=sys.stderr)
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    segment_with_cellpose(input_path, output_path)