process HOMER_ANNOTATEPEAKS_ALT {
    tag "${meta.id}"
    label 'process_medium'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/bioconductor-deseq2_bioconductor-edger_homer_samtools_pruned:9c603739ae7d4fd3'
        : 'community.wave.seqera.io/library/bioconductor-deseq2_bioconductor-edger_homer_samtools_pruned:08c7bb832e96c6bd'}"

    input:
    tuple val(meta), path(peak)
    val genome                   // genome version or path to fasta
    path gtf
    path tagdirs                 // Can be list of tag directories for -d option
    path motifs                  // Can be list of motif files for -m option
    path gene_data               // For -gene option
    path vcf                     // For -vcf option
    path bedgraph                // Can be list of bedGraph files
    path wiggle                  // Can be list of wiggle files
    path other_peaks             // Can be list of peak files for -p option

    output:
    tuple val(meta), path("*annotatePeaks.txt") , emit: txt
    tuple val(meta), path("*annStats.txt")      , emit: stats    , optional: true
    tuple val(meta), path("*.matrix.txt")       , emit: matrix   , optional: true
    tuple val(meta), path("*.bed")              , emit: bed      , optional: true
    tuple val(meta), path("*.fa")               , emit: fasta    , optional: true
    path "GO_*"                                 , emit: go       , optional: true
    path "GenomeOntology_*"                     , emit: genome_ontology, optional: true
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '5.1'
    
    // Handle optional inputs
    def gtf_cmd = gtf ? "-gtf ${gtf}" : ''
    def tagdir_cmd = tagdirs ? "-d ${tagdirs.join(' ')}" : ''
    def motif_cmd = motifs ? "-m ${motifs.join(' ')}" : ''
    def gene_cmd = gene_data ? "-gene ${gene_data}" : ''
    def vcf_cmd = vcf ? "-vcf ${vcf}" : ''
    def bedgraph_cmd = bedgraph ? "-bedGraph ${bedgraph.join(' ')}" : ''
    def wiggle_cmd = wiggle ? "-wig ${wiggle.join(' ')}" : ''
    def peak_cmd = other_peaks ? "-p ${other_peaks.join(' ')}" : ''
    
    """
    annotatePeaks.pl \\
        ${peak} \\
        ${genome} \\
        ${gtf_cmd} \\
        ${tagdir_cmd} \\
        ${motif_cmd} \\
        ${gene_cmd} \\
        ${vcf_cmd} \\
        ${bedgraph_cmd} \\
        ${wiggle_cmd} \\
        ${peak_cmd} \\
        ${args} \\
        > ${prefix}.annotatePeaks.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        homer: ${VERSION}
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '5.1'
    """
    touch ${prefix}.annotatePeaks.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        homer: ${VERSION}
    END_VERSIONS
    """
}