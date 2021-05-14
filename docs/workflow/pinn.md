# tips/pinn

This module implements the `trainer`, `sampler` and `labeller` processes with
the [PiNN](https://github.com/Teoroo-CMC/pinn) package. The `inp` should be a
PiNN model directory, for the `pinnTrain` process, the inp can 

### pinnTrain

| Inputs      | Default   | Description                                |
|-------------|-----------|--------------------------------------------|
| inp         | `null`    | PiNN model or params file                  |
| ds          | `null`    | trianing set                               |
| maxSteps    | `1000000` | max iteration [in steps]                   |
| pinnCache   | `"True"`  | cache preprocessed dataset during training |
| pinnBatch   | `10`      | batch size                                 |
| pinnCkpts   | `1`       | max number of checkpoints to save          |
| pinnShuffle | `500`     | shuffle buffer size                        |

Outputs the final model folder with checkpoints.

### pinnLabel
Label a dataset with PiNN

| Inputs | Default | Description  |
|--------|---------|--------------|
| inp    | `null`  | PiNN model   |
| ds     | `null`  | trianing set |

Outputs the labelled dataset.

### pinnSample

| Inputs    | Default | Description                            |
|-----------|---------|----------------------------------------|
| inp       | `null`  | PiNN model                             |
| init      | `null`  | initial Structure                      |
| pinnSeeds | `1`     | resample the traj with different seeds |
| pinnTime  | `5`     | sample time [ps]                       |
| pinnEvery | `0.01`  | sample every [ps]                      |

Outputs the sampled dataset.
