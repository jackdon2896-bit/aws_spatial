process FASTQ_TO_H5AD {
    tag "$meta.id"
    publishDir "${params.outdir}/h5ad_converted", mode: 'copy'
    
    conda "bioconda::scanpy=1.9.6 conda-forge::pandas=2.1.4 conda-forge::numpy=1.24.3"
    
    input:
    tuple val(meta), path(fastq_files)
    
    output:
    path "${meta.id}.h5ad", emit: h5ad
    
    script:
    """
    python ${projectDir}/bin/sra_to_h5ad.py ${meta.id} ${meta.id}.h5ad ${fastq_files.join(' ')}
    """
}