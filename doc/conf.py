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
