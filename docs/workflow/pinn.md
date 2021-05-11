# `tips/pinn`

### pinnTrain

| Inputs  | Default | Description               |
|---------|---------|---------------------------|
| inp     | `null`  | PiNN model or params file |
| ds      | `null`  | trianing set              |
| batch   | 1       | batch size                |
| maxIter | 1000000 | max iteration [in steps]  |

Outputs the final model folder with checkpoints.


### pinnLabel
Label a dataset with PiNN

| Inputs | Default | Description       |
|--------|---------|-------------------|
| inp    | `null`  | PiNN model folder |
| ds     | `null`  | trianing set      |

Outputs the labelled dataset.

### pinnSample

| Inputs | Default | Description                            |
|--------|---------|----------------------------------------|
| inp    |         | PiNN model                             |
| init   |         | initial Structure                      |
| seeds  |         | resample the traj with different seeds |
| time   |         | sample time [ps]                       |
| every  |         | sample every [ps]                      |

Outputs the sampled dataset.
