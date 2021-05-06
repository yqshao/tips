# Workflow overview

## Installation

Tips is not published yet. To use the TIPS workflows, just download the workflow
definitions to your working directory with, which should create a `tips`
directory in you working directory.

```shell
mkdir -p tips && curl https://codeload.github.com/yqshao/tips/tar.gz/master | \
  tar -C tips -xz --strip=2 tips-master/nextflow/
```

## Using a workflow

To run a workflow as it is, just run:

```shell
nf run tips/explore.nf --initDs my_ds.data #...
```

You might want to check the available options for each workflow.

## Reusing workflows

The Nextflow modules can be used as a sub-workflow in a more complex context. To
do so, import the workflow:

```groovy
#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include {explore} from './tips/explore'

inputs = Channel.of('pinet.yml', 'bpnn.yml')
                .map{[trainInp: it, subDir: "$it.baseName"]}

outputs = explore(inputs, null)
outputs.models.view()
```

The above script runs two `explore` experiments with different inputs for
training, each of them saved to a different directory. All workflows in TIPS
accepts two inputs, the first specifies all the required inputs, while the later
contains metadata which will be used to identify the outputs in a workflow (here
they are set to `null`). You can find the list of available workflows and their
options in [implemented workflows](implements.md).
