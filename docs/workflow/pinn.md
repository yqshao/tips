# tips/pinn

This module implements the `trainer`, `sampler` and `labeller` processes with
the [PiNN](https://github.com/Teoroo-CMC/pinn) package. The `inp` should be a
PiNN model directory, for the `pinnTrain` process, the inp can 

### pinnTrain

| Inputs  | Default   | Description               |
|---------|-----------|---------------------------|
| inp     | `null`    | PiNN model or params file |
| ds      | `null`    | trianing set              |
| batch   | `1`       | batch size                |
| maxIter | `1000000` | max iteration [in steps]  |

Outputs the final model folder with checkpoints.


### pinnLabel
Label a dataset with PiNN

| Inputs | Default | Description  |
|--------|---------|--------------|
| inp    | `null`  | PiNN model   |
| ds     | `null`  | trianing set |

Outputs the labelled dataset.

### pinnSample

| Inputs | Default | Description                            |
|--------|---------|----------------------------------------|
| inp    | `null`  | PiNN model                             |
| init   | `null`  | initial Structure                      |
| seeds  | `1`     | resample the traj with different seeds |
| time   | `5`     | sample time [ps]                       |
| every  | `0.01`  | sample every [ps]                      |

Outputs the sampled dataset.
