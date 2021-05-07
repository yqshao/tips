# Implementation workflows

## `tips/pinn`

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

## `tips/lammps`

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
