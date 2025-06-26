process NEXTPOLISH {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nextpolish:1.4.1--py39hd3f58dc_4' :
        'biocontainers/nextpolish:1.4.1--py312h4e9d295_4' }"

    input:
    tuple val(meta), path(reads), path(assembly)

    output:
    tuple val(meta), path("*.genome.nextpolish.fasta")        , emit: assembly
    tuple val(meta), path("*.genome.nextpolish.fasta.stat")   , emit: stats
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ls $reads > sgs.fofn

    mkdir -p libfix
    ln -s /usr/local/lib/libbz2.so.1.0.8 libfix/libbz2.so.1

    export LD_LIBRARY_PATH=\$(pwd)/libfix:/usr/local/lib:\$LD_LIBRARY_PATH
    export LD_PRELOAD=\$(pwd)/libfix/libbz2.so.1

    echo \\
        "[General]
         job_type = local
         job_prefix = ${prefix}
         task = best
         rewrite = yes
         rerun = 0
         parallel_jobs = $task.cpus
         multithread_jobs = $task.cpus
         genome = $assembly
         genome_size = auto
         workdir = \$(pwd)
         polish_options = -p $task.cpus
         
         [sgs_option]
         sgs_fofn = ./sgs.fofn
         sgs_options = -max_depth 100 -bwa" > run.cfg

    nextPolish run.cfg

    mv genome.nextpolish.fasta ${prefix}.genome.nextpolish.fasta
    mv genome.nextpolish.fasta.stat ${prefix}.genome.nextpolish.fasta.stat

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nextPolish: \$( nextPolish --version 2>&1 | sed 's/nextPolish //g' )
    END_VERSIONS
    """
}
