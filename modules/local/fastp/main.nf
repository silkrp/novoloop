process FASTP {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/88/889a182b8066804f4799f3808a5813ad601381a8a0e3baa4ab8d73e739b97001/data' :
        'community.wave.seqera.io/library/fastp:0.24.0--62c97b06e8447690' }"

    input:
    tuple val(meta), path(reads_fwd), path(reads_rev)

    output:
    tuple val(meta), path('*.fastp.fastq.gz')     , emit: fastq
    tuple val(meta), path('*.json')               , emit: json
    tuple val(meta), path('*.html')               , emit: html
    path 'versions.yml'                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    //def split = fastq_split > 0 ? "--split ${fastq_split}" : ''
    //def split = fastq_split > 0 ? "--split_by_lines ${4 * fastq_split}" : ''
    """
    fastp \\
        ${args} \\
        --in1 ${reads_fwd} \\
        --in2 ${reads_rev} \\
        --thread ${task.cpus} \\
        --out1 ${prefix}_R1.fastp.fastq.gz \\
        --out2 ${prefix}_R2.fastp.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed 's/^.* //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch 00{1..4}.${prefix}_R1.fastp.fastq.gz
    touch 00{1..4}.${prefix}_R2.fastp.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed 's/^.* //')
    END_VERSIONS
    """
}
