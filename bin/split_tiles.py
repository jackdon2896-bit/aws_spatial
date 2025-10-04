#!/usr/bin/env python3
"""
Split large TIFF images into smaller tiles for parallel processing.

This script divides a large TIFF image into manageable tiles to prevent
memory crashes during image processing. Each tile is saved with metadata
about its position in the original image.

Usage:
    python split_tiles.py <input.tif> <output_dir> <tile_size>

Example:
    python split_tiles.py large_image.tif tiles/ 1024
"""

import sys
import os
import tifffile as tiff
import numpy as np


def split_tiles(input_path, outdir, tile_size):
    """
    Split a TIFF image into tiles.
    
    Args:
        input_path: Path to input TIFF file
        outdir: Output directory for tiles
        tile_size: Size of each tile (square tiles: tile_size x tile_size)
    
    Returns:
        Number of tiles generated
    """
    # Create output directory
    os.makedirs(outdir, exist_ok=True)
    
    # Read the input image
    print(f"Reading image: {input_path}", file=sys.stderr)
    img = tiff.imread(input_path)
    
    # Get image dimensions
    if img.ndim == 2:
        h, w = img.shape
        channels = 1
    elif img.ndim == 3:
        h, w, channels = img.shape
    else:
        raise ValueError(f"Unexpected image dimensions: {img.shape}")
    
    print(f"Image shape: {img.shape}", file=sys.stderr)
    print(f"Tile size: {tile_size}x{tile_size}", file=sys.stderr)
    
    # Calculate number of tiles
    n_tiles_y = (h + tile_size - 1) // tile_size
    n_tiles_x = (w + tile_size - 1) // tile_size
    
    print(f"Will create {n_tiles_y} x {n_tiles_x} = {n_tiles_y * n_tiles_x} tiles", file=sys.stderr)
    
    # Generate tiles
    tile_id = 0
    for i in range(n_tiles_y):
        for j in range(n_tiles_x):
            # Calculate tile boundaries
            y_start = i * tile_size
            y_end = min(y_start + tile_size, h)
            x_start = j * tile_size
            x_end = min(x_start + tile_size, w)
            
            # Extract tile
            if img.ndim == 2:
                tile = img[y_start:y_end, x_start:x_end]
            else:
                tile = img[y_start:y_end, x_start:x_end, :]
            
            # Pad tile if it's at the edge (to maintain consistent size)
            if tile.shape[0] < tile_size or tile.shape[1] < tile_size:
                if img.ndim == 2:
                    padded = np.zeros((tile_size, tile_size), dtype=img.dtype)
                    padded[:tile.shape[0], :tile.shape[1]] = tile
                else:
                    padded = np.zeros((tile_size, tile_size, channels), dtype=img.dtype)
                    padded[:tile.shape[0], :tile.shape[1], :] = tile
                tile = padded
            
            # Create filename with position metadata
            tile_name = f"tile_{tile_id:04d}_y{y_start}_x{x_start}.tif"
            tile_path = os.path.join(outdir, tile_name)
            
            # Save tile
            tiff.imwrite(tile_path, tile)
            
            tile_id += 1
            if tile_id % 100 == 0:
                print(f"Generated {tile_id} tiles...", file=sys.stderr)
    
    print(f"✓ Generated {tile_id} tiles in {outdir}", file=sys.stderr)
    print(tile_id)  # Output for Nextflow to capture
    
    return tile_id


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: split_tiles.py <input.tif> <output_dir> <tile_size>", file=sys.stderr)
        sys.exit(1)
    
    input_path = sys.argv[1]
    outdir = sys.argv[2]
    tile_size = int(sys.argv[3])
    
    split_tiles(input_path, outdir, tile_size)
