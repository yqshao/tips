# Custom process

## Notes
- defaults holds all the default inputs for `trainer`
- parameters from the command line will overwrite the default values
- input channels update the defaults again as the actual input
- the default workflow invokes the workflow with an empty input
- `subDir` is a special options, it allows a "main" workflow to redirect the
  output of a sub-workflow.

## Template
Below is a template for implementing a custom labeller for TIPS

```groovy
params.publishDir      = 'mymodule'
params.publishMode     = 'link'

include {getParams} from './tips/utils'

defaults = [:]
defaults.subDir  = '.'
defaults.inp     = null
defaults.ds      = null
defaults.myParam = null
defaults = getParams(defaults, params)
process labeller {
    publishDir {"$params.publishDir/$setup.subDir"}, mode: params.publishMode

    input:
    tuple val(meta), val(input)

    output:
    tuple val{meta}, file("output.xyz") 

    script:
    setup = getParams(defaults, inputs)
    """
    my_code $setup.ds $setup.input $setup.myParam > output.xyz
    """
    
    stub:
    setup = getParams(defaults, inputs)
    """
    touch output.xyz
    """
}

workflow {
    labeller([null, [:]])
}
```



