# CP2K Format

CP2K outputs can be loaded from the `%PRINT%` sections or the log file. The
former can be loaded via the `tips.io.cp2k` module, the later via the
`tips.io.cp2klog` module.

**Note** that the CP2K format assumes atomic units, and loader uses CODATA
version 2006, as adapted by CP2K instead of the 2014 version used in ASE by
default.

## `tips.io.cp2k`

The `cp2k` module reads CP2K ouputs in written as specified in the
[%MOTION%PRINT%](https://manual.cp2k.org/trunk/CP2K_INPUT/MOTION/PRINT.html)
section. Those files are typically named as `path/proj-pos-1.xyz`,
`path/proj-frc-1.xyz`, etc, where the project name are specified in
[%GLOBAL%PROJECT_NAME%](https://manual.cp2k.org/trunk/CP2K_INPUT/GLOBAL.html#list_PROJECT_NAME).

??? "Source code"

    ```python
    --8<-- "tips/io/cp2k.py"
    ```

## `tips.io.cp2klog`

The `cp2klog` module reads in information as specified in
[%FORCE_EVAL%PRINT%](https://manual.cp2k.org/trunk/CP2K_INPUT/FORCE_EVAL/PRINT.html)
section. Those outputs will by wriiten by CP2K to stdout.

??? "Source code"

    ```python
    --8<-- "tips/io/cp2klog.py"
    ```