#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

params.publishDir      = 'lammps'
params.publishMode     = 'link'
include {getParams} from './utils'

labelDflts = [:]
labelDflts.subDir       = '.'
labelDflts.inp          = null
process lammpsLabel {
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    val inputs

    output:
    tuple val(inputs), path('label.{yml,tfr}')

    script:
    setup = getParams(labelDflts, inputs)
    """
    """

    script:
    setup = getParams(labelDflts, inputs)
    """
    #!/usr/bin/env bash
    touch label.{yml,tfr}
    """
}
