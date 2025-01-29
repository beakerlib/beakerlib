BeakerLib is a shell-level integration testing library, providing convenience
functions which simplify writing, running and analysis of integration
and blackbox tests.

## Installation

### Distribution support

#### Fedora / RHEL

One can install the packaged version directly from the Fedora repos.

The latest version can be found in the COPR [here](https://copr.fedorainfracloud.org/coprs/packit/beakerlib-beakerlib-master/).

### Installing from sources

To install the library to the root directory, use:

```
$ make
$ make install
```

If you need to install to a different directory, use
```
$ make
$ make DD=/path/to/directory install
```
Running against non-installed tree (except for the in-tree testsuite) is not supported.


## Links

Docs: https://beakerlib.readthedocs.io
