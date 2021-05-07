# Convert

Convert datasets between different formats.

## Usage

```
$ tips convert dsfile1 [dsfile2 ...] [options]
```

## Description

| Name, shorthand (if any) | Default          | Description                     |
|--------------------------|------------------|---------------------------------|
| -o                       | 'dataset'        | name of the output dataset      |
| --format, -f             | 'auto'           | format of input dataset         |
| --oformat, -of           | 'pinn'           | format of output dataset        |
| --splits, -s             | 'train:8,test:2' |                                 |
| --shuffle                | true             |                                 |
| --seed                   | 0                | random seed if shufffle is used |


The input `dsfile`s will be concatenated when converting. Note then when
`--split` is used, different `dsfiles` will be splitted separately before
concatenting the result to the output files.

## Example

From a lammps trajectory `npt.dump` to a dataset

```
$ tips convert npt.dump npt2.dump -o dataset 
```

