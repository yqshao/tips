#  Advanced

## Abstract workflows

Three types of abstract workflows, they are workflows that follows certain
input/output patterns, additional parameters can be present in the inputs
if necessary.

| Type     | Inputs                                                   | Output          |
|----------|----------------------------------------------------------|-----------------|
| trainer  | `[inp: model, ds:dataset, maxIter: iter, ... ], meta` | `models, meta`  |
| sampler  | `[inp: model, init: structure, ...], meta`               | `dataset, meta` |
| labeller | `[inp: model, ds:dataset, ...], meta`                    | `dataset, meta` |

The abstract workflows can be retrieve from the `adaptor` module, where the
exact version retrived according to `params`. For instance, the below script
trains two models with the same datasets with two different programes.

```groovy
params.trainer = 'pinn'
include {trainer as pinn} from './tips/adapter'
include {trainer as runner} from './tips/adapter', addParams(trainer:'runner')

inputs = Channel.of([ds: 'train.xyz'])
pinn_models = pinn(inputs.map{it+[subDir: 'pinn']}, null)
runner_models = runner(inputs.map{it+['subDir':, 'runner']}, null)
```

### Implemented abstract workflows

Below is a table of the abstract workflows available in TIPS.

| Name     | trainer   | sampler      | labeller    |
|----------|-----------|--------------|-------------|
| 'pinn'   | pinnTrain | pinnSample   | pinnLabel   |
| 'lammps' |           | lammpsSample | lammpsLabel |

### Custom abstract workflows
It is also possible to specify a custom trainer in the workflow by changing the
`trainer/sampler/labeller` parameter to a relative path starting with `./`, in
this case, adaptor will try to get such a general workflow from the script, in
that case, the workflow or process must be named as `trainer`, `sampler` or
`labeller` accordingly.

```groovy
params.trainer = './custom'
include {trainer} from './tips/adapter'
```

This is useful if you would like to reuse an active learning workflow, but
replace certain module.


## Example TIPS workflow

Below is a template for implementing a workflow for TIPS

```groovy
params.publishDir      = 'mymodule'
params.publishMode     = 'link'

include {getParams} from './tips/utils'

defaults = [:]
defaults.subDir = '.'
defaults.inp    = null
defaults.ds     = null
defaults = getParams(defaults, params)
process trainner {
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    tuple val(inputs), val(meta)

    output:
    tuple file("output"), val(meta) 

    script:
    setup = getParams(defaults, inputs)
    """
    touch output
    """
}

workflow {
    trianer([:])
}
```

- defaults holds all the default inputs for `trainer`
- parameters from the command line will overwrite the default values
- input channels update the defaults again as the actual input
- the default workflow invokes the workflow with an empty input
- `subDir` is a special options, it allows a "main" workflow to redirect the
  output of a sub-workflow. 

