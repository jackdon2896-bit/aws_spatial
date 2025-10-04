process SRA_DOWNLOAD {
    tag "$sra_id"
    publishDir "${params.outdir}/sra_downloads", mode: 'copy'
    
    conda "bioconda::sra-tools=3.0.10 bioconda::parallel-fastq-dump=0.6.7"
    
    input:
    val sra_id
    
    output:
    path "${sra_id}*.fastq.gz", emit: fastq
    path "${sra_id}.sra", emit: sra
    
    script:
    """
    # Download SRA file
    prefetch ${sra_id}
    
    # Convert to FASTQ
    parallel-fastq-dump \\
        --sra-id ${sra_id} \\
        --threads ${task.cpus} \\
        --outdir . \\
        --split-files \\
        --gzip
    
    # Keep the SRA file for reference
    cp ~/.ncbi/public/sra/${sra_id}.sra .
    """
}