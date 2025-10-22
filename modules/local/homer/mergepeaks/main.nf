process HOMER_MERGEPEAKS {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://community.wave.seqera.io/library/bioconductor-deseq2_bioconductor-edger_homer_samtools_pruned:9c603739ae7d4fd3'
        : 'community.wave.seqera.io/library/bioconductor-deseq2_bioconductor-edger_homer_samtools_pruned:08c7bb832e96c6bd'}"

    input:
    tuple val(meta), path(peaks) // peaks can be a list of peak files

    output:
    tuple val(meta), path("*_merged.txt"), emit: merged
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def peak_list = peaks instanceof List ? peaks : [peaks]
    def use_peak_file = peak_list.size() > 5
    def VERSION = '5.1'
    
    if (use_peak_file) {
        // Create file list using printf
        def peak_names = peak_list.collect { it.name }.join('\\n')
        """
        printf "${peak_names}\\n" > ${prefix}_peak_files.txt

        mergePeaks \\
            $args \\
            -file ${prefix}_peak_files.txt \\
            > ${prefix}_merged.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            homer: ${VERSION}
        END_VERSIONS
        """
    } else {
        // Use peaks directly
        """
        mergePeaks \\
            $args \\
            ${peaks.join(' ')} \\
            > ${prefix}_merged.txt

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            homer: ${VERSION}
        END_VERSIONS
        """
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '5.1'
    """
    touch ${prefix}_merged.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        homer: ${VERSION}
    END_VERSIONS
    """
}