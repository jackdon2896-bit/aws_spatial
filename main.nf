#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
========================================================================================
    AWS Spatial Transcriptomics Pipeline
========================================================================================
    Author: jackdon2896-bit
    Description: Spatial transcriptomics analysis for AWS HealthOmics
    Container: community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c
========================================================================================
*/

// Print help message
def helpMessage() {
    log.info"""
    =========================================
    AWS Spatial Transcriptomics Pipeline
    =========================================
    
    Usage:
    nextflow run main.nf --tiff <tiff_file> --h5 <h5_file> --markers <markers_file> --outdir <output_dir>
    
    Required arguments:
      --tiff          Path to TIFF image file (S3 or local)
      --h5            Path to H5 data file (S3 or local)
      --markers       Path to marker genes file (S3 or local)
      --outdir        Output directory (S3 or local)
    
    Optional arguments:
      --cellpose_model            Cellpose model (default: 'cyto2')
      --cellpose_diameter         Cell diameter (default: 30)
      --cellpose_flow_threshold   Flow threshold (default: 0.4)
      --cluster_resolution        Clustering resolution (default: 1.0)
      --n_neighbors               Number of neighbors (default: 15)
      --n_pcs                     Number of PCs (default: 50)
    
    Example:
      nextflow run main.nf \\
        --tiff s3://my-bucket/data/sample.tif \\
        --h5 s3://my-bucket/data/sample.h5 \\
        --markers s3://my-bucket/data/markers.csv \\
        --outdir s3://my-bucket/results \\
        -profile awshealthomics
    """.stripIndent()
}

// Show help message if requested
if (params.help) {
    helpMessage()
    exit 0
}

// Validate required parameters
if (!params.tiff || !params.h5 || !params.markers) {
    log.error "ERROR: Missing required parameters!"
    helpMessage()
    exit 1
}

/*
========================================================================================
    PROCESS: CELLPOSE_SEGMENT
========================================================================================
*/

process CELLPOSE_SEGMENT {
    container 'community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c'
    
    publishDir "${params.outdir}/segmentation", mode: 'copy'
    
    input:
    path tiff
    
    output:
    path "segmentation_masks.npy", emit: masks
    path "segmentation_flows.tif", emit: flows
    path "segmentation_stats.csv", emit: stats
    
    script:
    """
    #!/usr/bin/env python
    import numpy as np
    from cellpose import models
    import imageio.v2 as imageio
    import csv
    
    # Load image
    print("Loading image: ${tiff}")
    img = imageio.imread("${tiff}")
    
    # Initialize Cellpose model
    print("Initializing Cellpose model: ${params.cellpose_model}")
    model = models.Cellpose(model_type='${params.cellpose_model}')
    
    # Run segmentation
    print("Running segmentation...")
    masks, flows, styles, diams = model.eval(
        img,
        diameter=${params.cellpose_diameter},
        flow_threshold=${params.cellpose_flow_threshold},
        cellprob_threshold=${params.cellpose_cellprob_threshold}
    )
    
    # Save outputs
    print("Saving segmentation results...")
    np.save('segmentation_masks.npy', masks)
    imageio.imwrite('segmentation_flows.tif', flows[0])
    
    # Calculate statistics
    n_cells = len(np.unique(masks)) - 1  # Exclude background
    cell_sizes = [np.sum(masks == i) for i in range(1, n_cells + 1)]
    
    # Save statistics
    with open('segmentation_stats.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['metric', 'value'])
        writer.writerow(['total_cells', n_cells])
        writer.writerow(['mean_cell_size', np.mean(cell_sizes)])
        writer.writerow(['median_cell_size', np.median(cell_sizes)])
        writer.writerow(['min_cell_size', np.min(cell_sizes)])
        writer.writerow(['max_cell_size', np.max(cell_sizes)])
    
    print(f"Segmentation complete! Found {n_cells} cells")
    """
}

/*
========================================================================================
    PROCESS: EXTRACT_EXPRESSION
========================================================================================
*/

process EXTRACT_EXPRESSION {
    publishDir "${params.outdir}/expression", mode: 'copy'
    
    input:
    path h5
    path masks
    
    output:
    path "expression_matrix.csv", emit: matrix
    path "cell_metadata.csv", emit: metadata
    
    script:
    """
    #!/usr/bin/env python
    import numpy as np
    import h5py
    import csv
    
    # Load masks
    print("Loading segmentation masks...")
    masks = np.load("${masks}")
    n_cells = len(np.unique(masks)) - 1
    
    # Load H5 data
    print("Loading H5 data: ${h5}")
    with h5py.File("${h5}", 'r') as f:
        # Extract gene expression data
        # Adjust these keys based on your H5 structure
        if 'matrix' in f:
            expression = f['matrix'][:]
        elif 'X' in f:
            expression = f['X'][:]
        else:
            # Create dummy expression data for demonstration
            print("Warning: Creating dummy expression data")
            expression = np.random.rand(n_cells, 100)
    
    # Save expression matrix
    print("Saving expression matrix...")
    np.savetxt('expression_matrix.csv', expression, delimiter=',')
    
    # Create cell metadata
    print("Creating cell metadata...")
    with open('cell_metadata.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['cell_id', 'n_genes', 'total_counts'])
        for i in range(n_cells):
            cell_expr = expression[i, :] if i < expression.shape[0] else expression[0, :]
            n_genes = np.sum(cell_expr > 0)
            total_counts = np.sum(cell_expr)
            writer.writerow([f'cell_{i+1}', n_genes, total_counts])
    
    print(f"Expression extraction complete for {n_cells} cells")
    """
}

/*
========================================================================================
    PROCESS: SCRNA_CLUSTER
========================================================================================
*/

process SCRNA_CLUSTER {
    container 'community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c'
    
    publishDir "${params.outdir}/clustering", mode: 'copy'
    
    input:
    path expression_matrix
    
    output:
    path "clusters.csv", emit: clusters
    path "umap_coordinates.csv", emit: umap
    path "cluster_markers.csv", emit: markers
    
    script:
    """
    #!/usr/bin/env python
    import numpy as np
    import csv
    from sklearn.decomposition import PCA
    from sklearn.manifold import UMAP
    import leidenalg
    import igraph as ig
    
    # Load expression data
    print("Loading expression matrix...")
    expr = np.loadtxt("${expression_matrix}", delimiter=',')
    n_cells = expr.shape[0]
    
    # PCA for dimensionality reduction
    print("Running PCA...")
    pca = PCA(n_components=min(${params.n_pcs}, expr.shape[1], expr.shape[0]))
    expr_pca = pca.fit_transform(expr)
    
    # Build kNN graph
    print("Building kNN graph...")
    from sklearn.neighbors import NearestNeighbors
    nbrs = NearestNeighbors(n_neighbors=${params.n_neighbors}).fit(expr_pca)
    distances, indices = nbrs.kneighbors(expr_pca)
    
    # Create igraph object
    edges = []
    for i in range(len(indices)):
        for j in indices[i]:
            if i != j:
                edges.append((i, j))
    
    g = ig.Graph(edges)
    
    # Leiden clustering
    print("Running Leiden clustering...")
    partition = leidenalg.find_partition(
        g, 
        leidenalg.RBConfigurationVertexPartition,
        resolution_parameter=${params.cluster_resolution}
    )
    
    clusters = np.array(partition.membership)
    
    # UMAP for visualization
    print("Running UMAP...")
    umap_model = UMAP(n_neighbors=${params.n_neighbors}, min_dist=0.3, n_components=2)
    umap_coords = umap_model.fit_transform(expr_pca)
    
    # Save cluster assignments
    print("Saving cluster assignments...")
    with open('clusters.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['cell_id', 'cluster'])
        for i, cluster in enumerate(clusters):
            writer.writerow([f'cell_{i+1}', cluster])
    
    # Save UMAP coordinates
    with open('umap_coordinates.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['cell_id', 'UMAP_1', 'UMAP_2', 'cluster'])
        for i in range(len(umap_coords)):
            writer.writerow([f'cell_{i+1}', umap_coords[i, 0], umap_coords[i, 1], clusters[i]])
    
    # Find cluster markers (top differential genes)
    print("Finding cluster markers...")
    with open('cluster_markers.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['cluster', 'n_cells', 'mean_expression'])
        for cluster_id in np.unique(clusters):
            cluster_cells = clusters == cluster_id
            n_cells_cluster = np.sum(cluster_cells)
            mean_expr = np.mean(expr[cluster_cells, :])
            writer.writerow([cluster_id, n_cells_cluster, mean_expr])
    
    print(f"Clustering complete! Found {len(np.unique(clusters))} clusters")
    """
}

/*
========================================================================================
    PROCESS: SCRNA_ANNOTATE
========================================================================================
*/

process SCRNA_ANNOTATE {
    container 'community.wave.seqera.io/library/cellpose_celltypist_imageio_leidenalg_pruned:a05017b20bc0977c'
    
    publishDir "${params.outdir}/annotation", mode: 'copy'
    
    input:
    path expression_matrix
    path markers_file
    
    output:
    path "cell_types.csv", emit: cell_types
    path "annotation_scores.csv", emit: scores
    
    script:
    """
    #!/usr/bin/env python
    import numpy as np
    import csv
    
    # Load expression data
    print("Loading expression matrix...")
    expr = np.loadtxt("${expression_matrix}", delimiter=',')
    n_cells = expr.shape[0]
    
    # Load marker genes
    print("Loading marker genes from: ${markers_file}")
    markers = {}
    with open("${markers_file}", 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cell_type = row.get('cell_type', 'Unknown')
            if cell_type not in markers:
                markers[cell_type] = []
            # Store marker info (adjust based on your file format)
            markers[cell_type].append(row)
    
    # Simple annotation based on marker expression
    print("Annotating cells...")
    cell_types = []
    scores = []
    
    for i in range(n_cells):
        # Simple scoring: assign to cell type with highest marker expression
        best_score = 0
        best_type = "Unknown"
        
        for cell_type in markers:
            # Calculate score based on random expression for demo
            # Replace with actual marker-based scoring
            score = np.random.rand()
            if score > best_score:
                best_score = score
                best_type = cell_type
        
        cell_types.append(best_type)
        scores.append(best_score)
    
    # Save cell type annotations
    print("Saving cell type annotations...")
    with open('cell_types.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['cell_id', 'cell_type', 'confidence'])
        for i in range(n_cells):
            writer.writerow([f'cell_{i+1}', cell_types[i], scores[i]])
    
    # Save detailed scores
    with open('annotation_scores.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['cell_id'] + list(markers.keys()))
        for i in range(min(n_cells, 10)):  # Save first 10 for demo
            row = [f'cell_{i+1}'] + [np.random.rand() for _ in markers]
            writer.writerow(row)
    
    # Print summary
    from collections import Counter
    type_counts = Counter(cell_types)
    print("Cell type distribution:")
    for cell_type, count in type_counts.items():
        print(f"  {cell_type}: {count} cells")
    """
}

/*
========================================================================================
    WORKFLOW
========================================================================================
*/

workflow {
    // Create input channels
    tiff_ch = channel.fromPath(params.tiff, checkIfExists: true)
    h5_ch = channel.fromPath(params.h5, checkIfExists: true)
    markers_ch = channel.fromPath(params.markers, checkIfExists: true)
    
    // Run segmentation
    CELLPOSE_SEGMENT(tiff_ch)
    
    // Extract expression
    EXTRACT_EXPRESSION(h5_ch, CELLPOSE_SEGMENT.out.masks)
    
    // Cluster cells
    SCRNA_CLUSTER(EXTRACT_EXPRESSION.out.matrix)
    
    // Annotate cell types
    SCRNA_ANNOTATE(EXTRACT_EXPRESSION.out.matrix, markers_ch)
    
    // Print completion message
    workflow.onComplete {
        println ""
        println "Pipeline completed!"
        println "Status: ${workflow.success ? 'SUCCESS' : 'FAILED'}"
        println "Results: ${params.outdir}"
        println ""
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/
