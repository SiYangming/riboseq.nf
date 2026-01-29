process RIBOCODE_METAPLOTS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ribocode:1.2.15--pyhdc42f0e_1':
        'quay.io/biocontainers/ribocode:1.2.15--pyhdc42f0e_1' }"

    input:
    tuple val(meta), path(bam)
    tuple val(meta2), path(annotation)

    output:
    tuple val(meta), path("*config.txt")                                            , emit: config
    tuple val(meta), path("*.pdf")                                                  , emit: pdf
    path "versions.yml"                                                             , emit: versions_ribocode, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    metaplots \\
        -a $annotation \\
        -r $bam \\
        -o ${prefix} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        RiboCode: \$(RiboCode --version | sed 's/RiboCode //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_config.txt
    touch ${prefix}_report.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        RiboCode: \$(RiboCode --version | sed 's/RiboCode //')
    END_VERSIONS
    """
}
