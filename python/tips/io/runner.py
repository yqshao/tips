# -*- coding: utf-8 -*-

"""A RuNNer data loader

RuNNer data has the format

```
begin
lattice float float float
lattice float float float
lattice float float float
atom floatcoordx floatcoordy floatcoordz int_atom_symbol floatq 0  floatforcex floatforcey floatforcez
atom 1           2           3           4               5      6  7           8           9
energy float
charge float
comment arbitrary string
end
```

The order of the lines within the begin/end block are arbitrary. Coordinates,
charges, energies and forces are all in atomic units.

Originally written by: Matti Hellström
Adapted by: Yunqi Shao [yunqi.shao@kemi.uu.se]
"""

def ds2runner(dataset, fname):
    from ase.data import chemical_symbols
    bohr2ang = 0.5291772109
    lines = []
    for idx, data in enumerate(dataset):
        lines += ['begin\n', f'comment runner dataset generated by TIPS\n']
        c = data['cell']/bohr2ang
        for i in range(3):
            lines.append(f'lattice {c[i,0]:14.6e} {c[i,1]:14.6e} {c[i,2]:14.6e}\n')
        if 'stress' in data:
            s = data['stress']/bohr2ang**3
            for i in range(3):
                lines.append(f'stress  {s[i,0]:14.6e} {s[i,1]:14.6e} {s[i,2]:14.6e}\n')
        for e, c, f in zip(data['elem'], data['coord']/bohr2ang, data['force']*bohr2ang):
            lines.append(f'atom     {c[0]:14.6e} {c[1]:14.6e} {c[2]:14.6e}  '
                         f'{chemical_symbols[e]}  '
                         f'0.0    0.0   {f[0]:14.6e} {f[1]:14.6e} {f[2]:14.6e} \n')
        lines.append(f'energy  {data["energy"]:14.6e}\n')
        lines.append('charge 0.0\n')
        lines.append('end\n')
    with open(fname, 'w') as file:
        file.writelines(lines)
