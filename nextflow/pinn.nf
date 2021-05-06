#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

params.publishDir      = 'pinn'
params.publishMode     = 'link'

include {getParams} from './utils'

trainDflts = [:]
trainDflts.subDir        = '.'
trainDflts.inp           = null
trainDflts.ds            = null
trainDflts.maxSteps      = '1000000'
trainDflts.genDress      = true
trainDflts.cacheData     = 'True'
trainDflts.batchSize     = '10'
trainDflts.shuffleBuffer = '500'
trainDflts = getParams(trainDflts, params)
process pinnTrain {
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    val inputs

    output:
    tuple val(inputs), path('model/', type:'dir')

    script:
    setup = getParams(trainDflts, inputs)
    """
    tips split ${file(ds)}  -s 'train:8,eval:2' --seed $setup.seed
    [! -f ${file(setup.inp)}/params.yml ] \
        && { mkdir -p model; cp ${file(setup.inp)} model/params.yml; }\
        || {cp -r ${file(setup.inp)} model}
    pinn_train --model-dir='model' --params-file='model/params.yml'\
        --train-data='train.yml' --eval-data='eval.yml'\
        --cache-data=$setup.cacheData\
        --batch-size=$setup.bufferSize\
        --shuffle-buffer=$setup.shuffleBuffer\
        --train-steps=$setup.maxSteps\
        ${setup.genDress? "--regen-dress": ""}
    """
    stub:
    setup = getParams(trainDflts, inputs)
    """
    mkdir model
    """
}

sampleDflts = [:]
sampleDflts.subDir       = '.'
sampleDflts.model        = null
sampleDflts.sampleSeeds  = 1
sampleDflts.sampleTime   = 1
sampleDflts.sampleInterv = 1
sampleDflts = getParams(sampleDflts, params)
process pinnSample {
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    val inputs

    output:
    tuple val(inputs), path('sample.{traj,log,xyz}')

    script:
    setup = getParams(sampleDflts, inputs)
    """
    #!/usr/bin/env python3
    import pinn
    import numpy as np
    import tensorflow as tf
    from ase import units
    from ase.io import read, write
    from ase.io.trajectory import Trajectory
    from ase.md import MDLogger
    from ase.md.velocitydistribution import MaxwellBoltzmannDistribution
    from ase.md.nptberendsen import NPTBerendsen

    calc = pinn.get_calc("$setup.model/params.yml")
    for seed in range($setup.sampleSeeds):
        rng = np.random.default_rng(seed)
        atoms = read("$setup.init")
        atoms.set_calculator(calc)
        MaxwellBoltzmannDistribution(atoms, 330.*units.kB, rng=rng)
        dt = 0.5 * units.fs
        steps = int($setup.sampleTime*1e3*units.fs/dt)
        dyn = NPTBerendsen(atoms, timestep=dt, temperature=330, pressure=1,
                          taut=dt * 100, taup=dt * 1000, compressibility=4.57e-5)
        interval = int($setup.sampleInterv*1e3*units.fs/dt)
        dyn.attach(MDLogger(dyn, atoms, 'aug.log', mode="a"), interval=interval)
        dyn.attach(Trajectory('aug.traj', 'a', atoms).write, interval=interval)
        try:
            dyn.run(steps)
        except:
            pass
    """

    script:
    setup = getParams(sampleDflts, inputs)
    """
    #!/usr/bin/env bash
    touch sample.{traj,log,xyz}
    """
}

workflow {
    pinnTrain(Channel.of([:]))
}
