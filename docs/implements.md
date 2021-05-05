# Implemented workflow and processes

## Strategies

### Explore

`tips/explore` is an workflow in which a model is used to sample the configuration space

``` mermaid
graph LR
  A[initDs] --> B([trainer]);
  B --> C[model];
  C --> D([sampler]);
  D --> E{{tol?}} 
  E -- yes --> F[finalModel];
  E -- no --> G[augDs];
  G --> B;
```

| Inputs       | Description                   | Outputs | Description             |
|--------------|-------------------------------|---------|-------------------------|
| initDs       | initial dataset               | model   | final model given input |
| trainInit    | initial input for trainer     |         |                         |
| trainParam   | extra params for trainer      |         |                         |
| trainIter    | initial iteration trainer     |         |                         |
| trainSeeds   | number of seeds for qbc       |         |                         |
| retrainIter  | iteration retraining          |         |                         |
| sampleInit   | initial structure for sampler |         |                         |
| sampleparams | extra params for sampler      |         |                         |
| labelInp     | input for labbeller           |         |                         |
| maxIter      | max iteration                 |         |                         |

## PiNN 

### pinnTrain 
Trains a model with PiNN

| Inputs  | Description              | Outputs | Description              |
|---------|--------------------------|---------|--------------------------|
| inp     | PiNN model or params     | model   | trained model checkpoint |
| ds      | trianing set             |         |                          |
| batch   | batch size               |         |                          |
| maxIter | max iteration [in steps] |         |                          |



### pinnLabel 
Label a dataset with PiNN

| Inputs | Description  | Outputs | Description      |
|--------|--------------|---------|------------------|
| inp    | PiNN model   | label   | labelled dataset |
| ds     | trianing set |         |                  |

### pinnSample
Sammple a MD trajectory with PiNN

| Inputs | Description                            | Outputs | Description     |
|--------|----------------------------------------|---------|-----------------|
| inp    | PiNN model                             | ds      | sampled dataset |
| init   | initial Structure                      |         |                 |
| seeds  | resample the traj with different seeds |         |                 |
| time   | sample time [ps]                       |         |                 |
| every  | sample every [ps]                      |         |                 |

## Lammps

### lammpsSample
Sample a trajectory with Lammps

| Inputs | Description         | Outputs | Description     |
|--------|---------------------|---------|-----------------|
| inp    | lammps input script | ds      | sampled dataset |
| init   | initial Structure   |         |                 |

### lammpsLabel
Label a dataset with Lammps

| Inputs | Description          | Outputs | Description      |
|--------|----------------------|---------|------------------|
| inp    | lammps input script  | label   | labelled dataset |
| ds     | trianing set         |         |                  |

