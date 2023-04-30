# -*- coding: utf-8 -*-

import tips
import click
from .convert import convert
from .cp2kinp import cp2kinp


@click.command()
def version():
    click.echo(f"TIPS version: {tips.__version__}")


@click.group(context_settings={"show_default": True})
def entry():
    """TIPS CLI - A command line tool for manipulating of AML data"""
    pass


entry.add_command(convert)
entry.add_command(cp2kinp)
entry.add_command(version)
