#!/usr/bin/env nextflow

params.trainer  = 'pinn'
params.sampler  = 'pinn'
params.labeller = 'lammps'
params.filter   = ''

include {pinnTrain; pinnSample} from './pinn'
include {lammpsLabel} from './lammps'

process filter {
    input:
    ds

    output:
    file "filtered.{yml,tfr}"

    """
    tips filter $ds $params.filter -o filtered
    """
}

workflow trainer{
    take:
    inputs

    main:
    if (params.trainer!='pinn')
        throw new Exception("Trainer $params.trainer not implemented.")
    pinnTrain(inputs)

    emit:
    pinnTrain.out
}

workflow sampler{
    take:
    inputs

    main:
    switch (params.sampler) {
        case 'pinn':
            output = pinnSample(inputs);
            break;
        default:
            throw new Exception("sampler $params.sampler not implemented.");
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
