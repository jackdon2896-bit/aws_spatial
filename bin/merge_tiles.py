#!/usr/bin/env python3
"""
Merge processed tiles back into a full image.

This script reassembles tiles that were processed separately back into
a complete image, using the position metadata encoded in filenames.

Usage:
    python merge_tiles.py <tiles_dir> <output.tif> [original_height] [original_width]

Example:
    python merge_tiles.py processed_tiles/ merged.tif 4096 4096
"""

import sys
import os
import re
import tifffile as tiff
import numpy as np
from pathlib import Path


def parse_tile_info(filename):
    """
    Extract tile position from filename.
    
    Expected format: tile_XXXX_yYYYY_xXXXX.tif
    
    Returns:
        (tile_id, y_pos, x_pos) or None if parsing fails
    """
    pattern = r'tile_(\d+)_y(\d+)_x(\d+)\.tif'
    match = re.match(pattern, filename)
    
    if match:
        tile_id = int(match.group(1))
        y_pos = int(match.group(2))
        x_pos = int(match.group(3))
        return (tile_id, y_pos, x_pos)
    
    return None


def merge_tiles(tiles_dir, output_path, original_height=None, original_width=None):
    """
    Merge tiles back into a single image.
    
    Args:
        tiles_dir: Directory containing tile files
        output_path: Path for output merged image
        original_height: Optional original image height (for cropping padding)
        original_width: Optional original image width (for cropping padding)
    """
    # Find all tile files
    tile_files = sorted([f for f in os.listdir(tiles_dir) if f.endswith('.tif')])
    
    if not tile_files:
        raise ValueError(f"No tile files found in {tiles_dir}")
    
    print(f"Found {len(tile_files)} tiles to merge", file=sys.stderr)
    
    # Parse tile positions
    tiles_info = []
    for filename in tile_files:
        info = parse_tile_info(filename)
        if info:
            tiles_info.append((filename, info[1], info[2]))  # (filename, y, x)
        else:
            print(f"Warning: Could not parse filename {filename}", file=sys.stderr)
    
    if not tiles_info:
        raise ValueError("No valid tile files found")
    
    # Read first tile to get dimensions and dtype
    first_tile_path = os.path.join(tiles_dir, tiles_info[0][0])
    first_tile = tiff.imread(first_tile_path)
    tile_height, tile_width = first_tile.shape[:2]
    dtype = first_tile.dtype
    
    # Determine if color image
    is_color = first_tile.ndim == 3
    channels = first_tile.shape[2] if is_color else 1
    
    print(f"Tile dimensions: {tile_height}x{tile_width}", file=sys.stderr)
    print(f"Data type: {dtype}", file=sys.stderr)
    
    # Calculate output dimensions
    max_y = max(y for _, y, _ in tiles_info) + tile_height
    max_x = max(x for _, x, _ in tiles_info) + tile_width
    
    # Use original dimensions if provided, otherwise use calculated max
    output_height = original_height if original_height else max_y
    output_width = original_width if original_width else max_x
    
    print(f"Output dimensions: {output_height}x{output_width}", file=sys.stderr)
    
    # Create output array
    if is_color:
        merged = np.zeros((output_height, output_width, channels), dtype=dtype)
    else:
        merged = np.zeros((output_height, output_width), dtype=dtype)
    
    # Place tiles in output array
    for filename, y_pos, x_pos in tiles_info:
        tile_path = os.path.join(tiles_dir, filename)
        tile = tiff.imread(tile_path)
        
        # Calculate valid region (handle edge padding)
        y_end = min(y_pos + tile_height, output_height)
        x_end = min(x_pos + tile_width, output_width)
        
        tile_y_size = y_end - y_pos
        tile_x_size = x_end - x_pos
        
        # Place tile in merged image
        if is_color:
            merged[y_pos:y_end, x_pos:x_end, :] = tile[:tile_y_size, :tile_x_size, :]
        else:
            merged[y_pos:y_end, x_pos:x_end] = tile[:tile_y_size, :tile_x_size]
    
    # Save merged image
    print(f"Saving merged image to {output_path}", file=sys.stderr)
    tiff.imwrite(output_path, merged)
    
    print(f"✓ Successfully merged {len(tiles_info)} tiles", file=sys.stderr)
    print(f"✓ Output: {output_path} ({merged.shape})", file=sys.stderr)
    
    return merged.shape


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: merge_tiles.py <tiles_dir> <output.tif> [original_height] [original_width]", 
              file=sys.stderr)
        sys.exit(1)
    
    tiles_dir = sys.argv[1]
    output_path = sys.argv[2]
    
    # Optional original dimensions for cropping padding
    original_height = int(sys.argv[3]) if len(sys.argv) > 3 else None
    original_width = int(sys.argv[4]) if len(sys.argv) > 4 else None
    
    merge_tiles(tiles_dir, output_path, original_height, original_width)
