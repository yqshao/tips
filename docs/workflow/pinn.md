# `tips/pinn`

### pinnTrain

| Inputs      | Default   | Description                |
|-------------|-----------|----------------------------|
| inp         | `null`    | PiNN model or params file  |
| ds          | `null`    | trianing set               |
| maxIter     | `1000000` | max iteration [in steps]   |
| genDress    | `true`    | generate atomistic dress   |
| pinnBatch   | `10`      | batch size                 |
| pinnCache   | `"True"`  | cache preprocessed dataset |
| pinnShuffle | `500`     | shuffle buffer for PiNN    |

Outputs the final model folder with checkpoints.


### pinnLabel
Label a dataset with PiNN

| Inputs | Default | Description       |
|--------|---------|-------------------|
| inp    | `null`  | PiNN model folder |
| ds     | `null`  | trianing set      |

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
