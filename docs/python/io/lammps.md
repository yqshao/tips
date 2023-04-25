# tips.io.lammps

The `lammps` reads the lammps formatted `.dump` files, note that this
implementation only supports the limited format with the atom format: `ITEM:
ATOMS id type x y z`, any other format should fail with an error. For lammps
files it's common that the "real" elements information is stored in a separate
`.data` file. The element can be converted easily with the `.map_elems()` method
of the `Dataset` class.

??? "Source code"

    ```python
    --8<-- "tips/io/lammps.py"
    ```
