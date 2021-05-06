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

metadata = Channel.value(null)
inputs = Channel.of('pinet.yml', 'bpnn.yml')
                .map{[trainInp: it, subDir: "$it.baseName"]}

outputs = explore(metadata.combine(inputs))
```

All workflows in TIPS follows a same pattern for input/output, all inputs should
be a tuple of [metadata, inputs], and workflow outputs [metadata, output]. The
metadata is copied to the output, for the outer workflow to identify the
outputs. The inputs are maps that specifies the options of the workflow. You can
find the list of inputs for each workflow implemented in [implemented
workflows](implements.md). Here, we set the metadata to `null`, and iterate over
different training parameters in the inputs.
