# ASE Format

The `tips.io.ase` module allows the loading of ase-supported trajectories from
the TIPS Dataset.

Writer for `asetraj` and `extxyz` extends the original ASE file writers, and
adds additional columns such as `force_std` which one might obtain in an
ensemble-based MD simulation.

??? "Source code"

    ```python
    --8<-- "tips/io/ase.py"
    ```
