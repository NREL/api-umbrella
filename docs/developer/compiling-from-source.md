# Compiling From Source

Installing from a [binary package](../getting-started.html#installation) is recommended, if available ([let us know](https://github.com/NREL/api-umbrella/issues/new) if you'd like to see binary packages for other platforms). However, if you'd like to compile from source, follow these instructions:

## Prerequisites

- 64bit Linux distribution
  - It should be possible to run against other 64bit *nix operating systems, but our build script currently has some hard-coded assumptions to a 64bit linux environment. [File an issue](https://github.com/NREL/api-umbrella/issues/new) if you'd like to see other operating systems supported.
- The following packages, or their equivalent for your distro (these are extracted from our [build script](https://github.com/NREL/api-umbrella/blob/master/build/package/build)):
  - CentOS:
    - bash
    - bzip2
    - curl
    - gcc
    - gcc-c++
    - git
    - glibc
    - initscripts
    - java-1.8.0-openjdk-headless
    - libffi
    - libffi-devel
    - libuuid-devel
    - libxml2
    - libxml2-devel
    - libyaml
    - libyaml-devel
    - make
    - ncurses-devel
    - ncurses-libs
    - openssl
    - openssl-devel
    - patch
    - pcre
    - pcre-devel
    - rsync
    - tar
    - tcl
    - tcl-devel
    - unzip
    - util-linux-ng
    - which
    - xz
    - zlib
  - Ubuntu:
    - bash
    - bzip2
    - curl
    - g++
    - gcc
    - git
    - libc6
    - libffi-dev
    - libncurses5
    - libncurses5-dev
    - libpcre3
    - libpcre3-dev
    - libssl-dev
    - libxml2
    - libxml2-dev
    - libyaml-0-2
    - libyaml-dev
    - lsb-base
    - lsb-release
    - make
    - openjdk-7-jre-headless
    - openssl
    - patch
    - rsync
    - sysvinit-utils
    - tar
    - tcl
    - tcl-dev
    - unzip
    - uuid-dev
    - uuid-dev
    - xz-utils
    - zlib1g

## Compiling & Installing

```sh
$ curl -OLJ https://github.com/NREL/api-umbrella/archive/v0.11.1.tar.gz
$ tar -xvf api-umbrella-0.11.1.tar.gz
$ cd api-umbrella-0.11.1
$ make
$ sudo make install
```
