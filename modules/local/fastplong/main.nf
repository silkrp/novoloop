process FASTPLONG {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastplong:0.2.2--heae3180_0' :
        'biocontainers/fastplong:0.2.2--heae3180_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*.fastplong.fastq.gz')   , emit: reads
    tuple val(meta), path('*.json')                 , emit: json
    tuple val(meta), path('*.html')                 , emit: html
    tuple val(meta), path('*.log')                  , emit: log
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    [ ! -f  ${prefix}.fastq.gz ] && ln -sf $reads ${prefix}.fastq.gz

    fastplong \\
        --in ${prefix}.fastq.gz \\
        --out ${prefix}.fastplong.fastq.gz \\
        --thread $task.cpus \\
        --json ${prefix}.fastplong.json \\
        --html ${prefix}.fastplong.html \\
        $args \\
        2> >(tee ${prefix}.fastplong.log >&2)

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastplong: \$(fastplong --version 2>&1 | sed -e "s/fastplong //g")
    END_VERSIONS
    """

    stub:
    def prefix              = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}.fastplong.fastq.gz"
    touch "${prefix}.fastplong.json"
    touch "${prefix}.fastplong.html"
    touch "${prefix}.fastplong.log"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastplong: \$(fastplong --version 2>&1 | sed -e "s/fastplong //g")
    END_VERSIONS
    """
}
