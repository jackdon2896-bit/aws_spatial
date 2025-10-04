#!/usr/bin/env python
import sys
import scanpy as sc
import argparse

def main():
    parser = argparse.ArgumentParser(description='QC for scRNA-seq data')
    parser.add_argument('input', help='Input H5 file')
    parser.add_argument('--genes', help='Comma-separated gene IDs to filter', default=None)
    
    # Handle both positional and argument-based input
    if '--genes' in sys.argv:
        args = parser.parse_args()
        input_file = args.input
        gene_ids = args.genes
    else:
        input_file = sys.argv[1]
        gene_ids = None
    
    # Read data
    try:
        adata = sc.read_10x_h5(input_file)
    except:
        # If not 10x format, try generic h5ad
        adata = sc.read(input_file)
    
    # Basic QC filtering
    sc.pp.filter_cells(adata, min_genes=200)
    sc.pp.filter_genes(adata, min_cells=3)
    
    # Calculate QC metrics
    adata.var['mt'] = adata.var_names.str.startswith('MT-')
    sc.pp.calculate_qc_metrics(adata, qc_vars=['mt'], percent_top=None, log1p=False, inplace=True)
    
    # Filter based on QC metrics
    adata = adata[adata.obs.n_genes_by_counts < 2500, :]
    adata = adata[adata.obs.pct_counts_mt < 20, :]
    
    # Gene filtering if specified
    if gene_ids:
        gene_list = [g.strip() for g in gene_ids.split(',')]
        # Check which genes are present
        available_genes = [g for g in gene_list if g in adata.var_names]
        if available_genes:
            print(f"Filtering for genes: {', '.join(available_genes)}")
            adata = adata[:, adata.var_names.isin(available_genes)]
        else:
            print(f"Warning: None of the specified genes found in dataset")
    
    adata.write("qc.h5ad")
    print(f"QC complete: {adata.n_obs} cells, {adata.n_vars} genes")

if __name__ == '__main__':
    main()