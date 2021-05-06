#!/usr/bin/env nextflow
nextflow.enable.dsl=2

// parameters trainer/sampler/labeller can be replaced with processes
params.publishDir     = 'explore'
params.trainer        = 'pinn'
params.sampler        = 'pinn'
params.labeller       = 'lammps'
params.maxIter        = '10'
params.resFilter      = '-vmax "e:-42" -amax "f:4"'
params.augFilter      = '-vmax "e:-30" -amax "f:8"'
params.qbcFilter      = ''
// other parameters can be are adjusted with the inputs channel, defaults listed below
defaults = [:]
defaults.subDir       = '.'
defaults.initDs       = null
defaults.trainInp     = null
defaults.trainSeeds   = '3'
defaults.trainSteps   = '200000'
defaults.retrainSteps = '200000'
defaults.sampleInp    = '["ensemble":"NPT", "time":5, "every":0.001, "T": 330]'
defaults.sampleInit   = 'init.xyz'
defaults.labelInp     = 'label.lmp'

include {iterUntil; setNext} from './utils'
include {trainer;sampler;labeller} from './adaptor'
include {filter as augFilter} from './adaptor', addParams(filter:params.augFilter)
include {filter as resFilter} from './adaptor', addParams(filter:params.resFilter)

workflow explore {
    take:
    inputs

    main:
    condition = {it[0].iter>=params.maxIter}
    defaults = getParams(defaults, params)
    setup = inputs.map{[it[1]+[meta:it[0]], getParams(defaults, it)]}.collect(se)
        .flatMap{(1..it[1].trainSeeds).collect(seed->[it[0]+[seed:seed], it[1]]}}

    // initalize the first iteration, only sample and label the first seed
    initDs      = setup.map{[it[0], [ds: it[1].initDs, seeds: it[1].trainSeeds]]}
    initCkpt    = setup.map{[it[0], [inp: it[1].trainInp]]}
    initSteps   = setup.map{[it[0], [maxSteps: it[1].trainSteps.toInteger(), retrainSteps: it[1].retrainSteps.toInteger()]]}
    initSample  = setup.map{[it[0], [init: it[1].sampleInit, inp: it[1].sampleInp]]}
    initLabel   = setup.map{[it[0], [inp: it[1].labelInp]]}

    // create the iterating channels
    trainDs,    nextDs     = iterUntil(initDs,     condition)
    trainCkpt,  nextCkpt   = iterUntil(initCkpt,   condition)
    trainSteps, nextSteps  = iterUntil(initSteps,  condition)
    sampleInp,  nextSample = iterUntil(initSample, condition)
    labelInp,   nextlabel  = iterUntil(initSample, condition)

    // the actual work for each iteraction
    trainInp   = trainDs.join(trainCkpt).join(trainSteps).map{[it[0], [ds:it[1].ds]+it[2]+[maxSteps:it[3].maxSteps]]}
    models     = trainer(trainInp)
    sampleInp  = sampleInp.join(model).map{[it[0], it[1]+[model:it[2]]]}
    traj       = sampler(sampleInp)
    labelInp   = labelInp.join(traj).map{[it[0], it[1]+[ds:it[2]]]}
    labels     = labeller(labelInp)
    augDs      = augFilter(labels)
    restart    = resFilter(labels)

    // prepare for the next iteration
    setNext(nextDs,     trainDs.join(augDs).flatMap{(1..it[1].seeds).collect{[it[0]+[seed:seed], it[1]+[ds:[]<<it[1].ds<<it[2]]]}})
    setNext(nextCkpt,   models.map{[it[0], [inp: it[1].model]]})
    setNext(nextSteps,  trainSteps.map{[it[0], it[1]+[maxSteps: it[1].maxSteps+it[1].retrainSteps]]})
    setNext(nextSample, sampleInp.join(restart).map{[it[0],it[1]+[init:it[2]]]})
    setNext(nextLabel,  labelInp)

    emit:
    models.filter{it[0].seed==1}
        .map{[it[0].findAll(k,v->k!='iter'&k!='seed'), it[1]]}
        .groupTuple().map{it[0].meta, it[1][-1]}
}

workflow {
    explore(Channel.of([:]))
}
