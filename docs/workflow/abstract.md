# Abstract workflows

Three types of abstract workflows are implemented in TIPS, they are workflows
that follows certain input/output patterns, additional parameters can be present
in the inputs if necessary.

| Type     | Required Inputs                                | Output  |
|----------|------------------------------------------------|---------|
| trainer  | `[inp: model, ds:dataset, maxIter: iter, ...]` | models  |
| sampler  | `[inp: model, init: structure, ...]`           | dataset |
| labeller | `[inp: model, ds:dataset, ... ]`               | dataset |
| filter   | `[params: parameters, ds:dataset, ...]`        | dataset |

## Usage

The abstract workflows can be retrieve from the `adaptor` module, where the
exact version retrived according to `param`. For instance, the below script
trains two models with the same datasets with two different programs.

```groovy
params.trainer = 'pinn'
include {trainer as pinn} from './tips/adapter'
include {trainer as runner} from './tips/adapter', addParams(trainer:'runner')

meta = Channel.value(null)
inputs = Channel.of([ds: 'train.xyz'])

workflow{
  inputs | map{it+[subDir: 'pinn']}   | meta.combine | pinn
  inputs | map{it+[subDir: 'runner']} | meta.combine | runner
}
```

## Implemented

Below is a table of the abstract workflows available in TIPS.

| Name   | trainer   | sampler      | labeller    | filter     |
|--------|-----------|--------------|-------------|------------|
| pinn   | pinnTrain | pinnSample   | pinnLabel   |            |
| lammps |           | lammpsSample | lammpsLabel |            |
| tips   |           |              |             | tipsFilter |

Their options and explanations can be found in the implementations section.

## Customization
It is also possible to specify a custom workflow in the workflow by changing the
`trainer`, `sampler` or `labeller` parameter to a relative path starting with
`./`, in this case, adaptor will try to get such a general workflow from the
script, in that case, the workflow or process must be named as `trainer`,
`sampler` or `labeller` accordingly.

```groovy
params.trainer = './custom'
include {trainer} from './tips/adapter'
```

This is useful if you would like to reuse an active learning workflow, but
replace certain module.

## Template
Below is a template for implementing a custom labeller for TIPS

```groovy
params.publishDir      = 'mymodule'
params.publishMode     = 'link'

include {getParams} from './tips/utils'

defaults = [:]
defaults.subDir = '.'
defaults.inp    = null
defaults.ds     = null
defaults = getParams(defaults, params)
process labeller {
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    tuple val(meta), val(input)

    output:
    tuple val{meta}, file("output") 

    script:
    setup = getParams(defaults, inputs)
    """
    touch output
    """
}

workflow {
    labeller([null, [:]])
}
```

- defaults holds all the default inputs for `trainer`
- parameters from the command line will overwrite the default values
- input channels update the defaults again as the actual input
- the default workflow invokes the workflow with an empty input
- `subDir` is a special options, it allows a "main" workflow to redirect the
  output of a sub-workflow.
