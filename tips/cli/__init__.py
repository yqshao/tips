# -*- coding: utf-8 -*-

import click
from .main import convert, subsample, version
from .utils import mkcp2kinp


@click.group()
def entry():
    """TIPS CLI - A command line tool for manipulating of AML data"""
    pass


entry.add_command(convert)
entry.add_command(subsample)
entry.add_command(version)


@entry.group()
def utils():
    pass


utils.add_command(mkcp2kinp)
