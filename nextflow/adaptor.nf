#!/usr/bin/env nextflow

params.trainer  = 'pinn'
params.sampler  = 'pinn'
params.labeller = 'lammps'
params.filter   = 'tips'

// All known implementations
include {pinnTrain; pinnSample} from "$moduleDir/pinn"
include {lammpsLabel; lammpsSample} from "$moduleDir/lammps"
include {tipsFilter} from "$moduleDir/tips"

workflow filter{
    take:
    inputs

    main:
    switch (params.filter) {
        case 'tips':
            output = tipsFilter(inputs);
            break;
        default:
            throw new Exception("Unkown filter $params.filter.");
    }

    emit:
    output
}

workflow trainer{
    take:
    inputs

    main:
    switch (params.trainer) {
        case 'pinn':
            output = pinnTrain(inputs);
            break;
        default:
            throw new Exception("Unknown trainer $params.trainer.");
    }

    emit:
    output
}

workflow sampler{
    take:
    inputs

    main:
    switch (params.sampler) {
        case 'pinn':
            output = pinnSample(inputs);
            break;
        case 'lammps':
            output = lammpsSample(inputs);
            break;
        default:
            throw new Exception("Unknown sampler $params.sampler.");
    }

    emit:
    output
}

workflow labeller{
    take:
    inputs

    main:
    switch (params.labeller) {
        case 'pinn':
            output = pinnLabel(inputs);
            break;
        case 'lammps':
            output = lammpsLabel(inputs);
            break;
        default:
            throw new Exception("sampler $params.labeller not implemented.");
    }

    emit:
    output
}
