# Compiling From Source

Installing from a [binary package](../getting-started.html#installation) is recommended, if available ([let us know](https://github.com/NREL/api-umbrella/issues/new) if you'd like to see binary packages for other platforms). However, if you'd like to compile from source, follow these instructions:

## Prerequisites

- 64bit Linux distribution
  - It should be possible to run against other 64bit *nix operating systems, but our build script currently has some hard-coded assumptions to a 64bit linux environment. [File an issue](https://github.com/NREL/api-umbrella/issues/new) if you'd like to see other operating systems supported.
- Dependencies can automatically be installed for supported distributions by running the `./build/scripts/install_build_dependencies` script. For unsupported distributions, view the `./build/package_dependencies.sh` file for a list of required packages.

## Compiling & Installing

```sh
$ curl -OLJ https://github.com/NREL/api-umbrella/archive/v0.14.4.tar.gz
$ tar -xvf api-umbrella-0.14.4.tar.gz
$ cd api-umbrella-0.14.4
$ sudo ./build/scripts/install_build_dependencies
$ ./configure
$ make
$ sudo make install
```
