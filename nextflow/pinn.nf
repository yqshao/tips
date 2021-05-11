#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

params.publishDir      = 'pinn'
params.publishMode     = 'link'

include {fileList; getParams} from "$moduleDir/utils"

trainDflts = [:]
trainDflts.subDir        = '.'
trainDflts.inp           = null
trainDflts.ds            = null
trainDflts.seed          = 0
trainDflts.maxSteps      = '1000000'
trainDflts.genDress      = true
trainDflts.cacheData     = 'True'
trainDflts.batchSize     = '10'
trainDflts.shuffleBuffer = '500'
trainDflts = getParams(trainDflts, params)
process pinnTrain {
    label 'pinn'
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    tuple val(meta), val(inputs)

    output:
    tuple val(meta), path('model/', type:'dir')

    script:
    setup = getParams(trainDflts, inputs)
    """
    tips split ${fileList(setup.ds)} -s 'train:8,eval:2' --seed $setup.seed
    if [ ! -f ${file(setup.inp)}/params.yml ];  then
        mkdir -p model; cp ${file(setup.inp)} model/params.yml
    else
        cp -r ${file(setup.inp)} model
    fi
    pinn_train --model-dir='model' --params-file='model/params.yml'\
        --train-data='train.yml' --eval-data='eval.yml'\
        --cache-data=$setup.cacheData\
        --batch-size=$setup.batchSize\
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
sampleDflts.inp          = null
sampleDflts.init         = null
sampleDflts.seeds        = 1
sampleDflts.time         = 5
sampleDflts.interv       = 0.01
sampleDflts = getParams(sampleDflts, params)
process pinnSample {
    label 'pinn'
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    tuple val(meta), val(inputs)

    output:
    tuple val(meta), path('output.xyz')

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

    calc = pinn.get_calc("${file(setup.inp)}/params.yml")
    for seed in range($setup.seeds):
        rng = np.random.default_rng(seed)
        atoms = read("${file(setup.init)}")
        atoms.set_calculator(calc)
        MaxwellBoltzmannDistribution(atoms, 330.*units.kB, rng=rng)
        dt = 0.5 * units.fs
        steps = int($setup.time*1e3*units.fs/dt)
        dyn = NPTBerendsen(atoms, timestep=dt, temperature=330, pressure=1,
                          taut=dt * 100, taup=dt * 1000, compressibility=4.57e-5)
        interval = int($setup.interv*1e3*units.fs/dt)
        dyn.attach(MDLogger(dyn, atoms, 'output.log', mode="a"), interval=interval)
        dyn.attach(Trajectory('output.traj', 'a', atoms).write, interval=interval)
        try:
            dyn.run(steps)
        except:
            pass
    traj = read('output.traj', index=':')
    [atoms.wrap() for atoms in traj]
    write('output.xyz', traj)
    """

    stub:
    setup = getParams(sampleDflts, inputs)
    """
    #!/usr/bin/env bash
    touch output.xyz
    """
}

workflow {
    pinnTrain(Channel.of([:]))
}
