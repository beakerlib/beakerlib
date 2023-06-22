import os
import subprocess
import sys
from sphinx.application import Sphinx

project = 'BeakerLib'
copyright = '2023, Dalibor Pospíšil'
author = 'Dalibor Pospíšil'

extensions = [
    "myst_parser",
    "sphinx_design",
    "sphinx_togglebutton",
    "breathe",
]

templates_path = []
exclude_patterns = [
    'build',
    '_build',
    'Thumbs.db',
    '.DS_Store',
    "README.md",
]
source_suffix = [".md"]

html_theme = 'furo'
html_static_path = ['_static']

myst_enable_extensions = [
    "tasklist",
    "colon_fence",
]


def run_make_pod(app: Sphinx):
    try:
        with open("man.md", "w") as file:
            os.chdir(f"{app.confdir}/../src")
            subprocess.run(["make", "docs/pod/beakerlib.pod"])
            # Fix the header level to not conflict with page title
            sed = subprocess.Popen(["sed", "s/^#/##/g"], stdin=subprocess.PIPE, stdout=file)
            pod2md = subprocess.Popen(["pod2markdown", "docs/pod/beakerlib.pod"], stdout=sed.stdin)
            sed.communicate()
            pod2md.wait()
    except OSError:
        sys.stderr.write("Failed to generate perl pod documentations")
        raise


def setup(app: Sphinx):
    app.connect("builder-inited", run_make_pod)
