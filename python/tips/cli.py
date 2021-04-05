#!/usr/bin/env python3
import tips
import click
from tips.io import read, get_writer

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])

@click.group()
def main():
    """TIPS CLI - A command line tool for manipulating of AML data"""
    pass

@click.command()
def version():
    click.echo(f'TIPS version: {tips.__version__}')

@click.command(name='convert', context_settings=CONTEXT_SETTINGS, short_help='convert datasets')
@click.argument('filename')
@click.option('--log', metavar='', default=None, help='lammps log (for energies)')
@click.option('--emap', metavar='', default=None, help='remap lammps elements, e.g. "1:1,2:8"')
@click.option('-f', '--format', metavar='', default='auto', help='input format')
@click.option('-o', '--output', metavar='', default='dataset')
@click.option('-of', '--oformat', metavar='', default='pinn', help='output format')
def convertds(filename, log, format, output, oformat, emap):
    dataset = read(filename, format=format, log=log, emap=emap)
    writer = get_writer(output, format=oformat)
    with click.progressbar(dataset, show_pos=True, bar_template='Converting: %(info)s structures.') as ds:
        for datum in ds:
            writer.add(datum)
    writer.finalize()

@click.command(name='split', context_settings=CONTEXT_SETTINGS, short_help='split datasets')
@click.argument('filename')
@click.option('--log', metavar='', default=None, help='lammps log (for energies)')
@click.option('--emap', metavar='', default=None, help='remap lammps elements, e.g. "1:1,2:8"')
@click.option('-s', '--splits', metavar='', default='train:8,test:2', help='name and ratio of splits')
@click.option('--shuffle', metavar='', default=True, help='shuffle the dataset')
@click.option('--seed', metavar='', default='0',  type=int, help='seed for random number (int)')
@click.option('-f', '--format', metavar='', default='auto', help='input format')
@click.option('-of', '--oformat', metavar='', default='pinn', help='output format')
def splitds(filename, log, format, splits, shuffle, seed, oformat, emap):
    import random, itertools, math, time
    dataset = read(filename, format=format, log=log, emap=emap)
    dataset, ds4count = itertools.tee(dataset)
    count = sum(1 for _ in ds4count)
    writers = [get_writer(s.split(':')[0], format=oformat) for s in splits.split(',')]
    weights = [float(s.split(':')[1]) for s in splits.split(',')]
    writers = sum([[writer]*math.ceil(count*weight/sum(weights))
                   for writer, weight in zip(writers, weights)],[])
    if shuffle:
        random.seed(seed)
        random.shuffle(writers)
    with click.progressbar(dataset, length=count, show_pos=True) as ds:
        for datum, writer in zip(ds, writers):
            writer.add(datum)
    [writer.finalize() for writer in writers]

@click.command(name='filter', context_settings=CONTEXT_SETTINGS, short_help='filter datasets')
@click.argument('filename', nargs=-1)
@click.option('-f', '--format', metavar='', default='auto', help='input format')
@click.option('-o', '--output', metavar='', default='dataset')
@click.option('-of', '--oformat', metavar='', default='pinn', help='output format')
@click.option('-a', '--algo', metavar='', default='naive', help='filtering algorithm')
@click.option('-et', '--error-tol', metavar='', default=None, help='error tolerance')
@click.option('-ef', '--error-file', metavar='', default=None, help='error file')
@click.option('-ft', '--frac-tol', metavar='', default=None, help='fraction tolerance')
@click.option('-fp', '--fingerprint', metavar='', default=None, help='fingerprint name')
def filterds(filename, output, format, oformat, algo, error_tol, error_file, frac_tol, fingerprint):
    """\b
    Algorithms available:
    - 'naive': filter by the error tolerance
    - 'qbc': query by committee
    - 'fps': furthest point sampling

    For the naive algorithm, one of error-tol and frac-tol must be given to
    specify the criterion of filtering. If many error labels exist, multiple
    toleracnce can be selected with e.g. "-et energy:0.1,force:0.01".

    For the qbc algorithm, a list of datasets with the SAME structures and ordering
    is required and their standard deviation is used as the error.

    For the FPS algorithm, no error file is required but a fingerprint is required
    to specify the fingerprint/descriptor with which the distance is computed.
    """
    import numpy as np
    writer = get_writer(output, format=oformat)
    if algo=='qbc':
        ds = [read(fname, format=format) for fname in filename]
        tols = {s.split(':')[0]: float(s.split(':')[1]) for s in error_tol.split(',')}
        for data in zip(*ds):
            for k, tol in tols.items():
                error = np.std([datum[f'{k}_data'] for datum in data], axis=0)
                if (error>tol).any():
                    writer.add(data[0])
        writer.finalize()
    else:
        raise NotImplementedError

@click.command(name='merge', context_settings=CONTEXT_SETTINGS, short_help='filter datasets')
@click.argument('filename', nargs=-1)
@click.option('-f', '--format', metavar='', default='auto', help='input format')
@click.option('-o', '--output', metavar='', default='dataset')
@click.option('-of', '--oformat', metavar='', default='pinn', help='output format')
def mergeds(filename, output, format, oformat):
    writer = get_writer(output, format=oformat)
    for fname in filename:
        ds = read(fname, format=format)
        for data in ds:
            writer.add(data)
    writer.finalize()

main.add_command(convertds)
main.add_command(splitds)
main.add_command(filterds)
main.add_command(mergeds)
main.add_command(version)

if __name__ == '__main__':
    main()
