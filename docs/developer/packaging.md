# Building Binary Packages

## Prerequisites

- git
- Docker

## Supported Distributions

Currently we build 64bit binary packages for the following distributions:

- Debian 7 (Wheezy)
- Debian 8 (Jessie)
- Enterprise Linux 6 (CentOS/RedHat/Oracle/Scientific Linux)
- Enterprise Linux 7 (CentOS/RedHat/Oracle/Scientific Linux)
- Ubuntu 12.04 (Precise)
- Ubuntu 14.04 (Trusty)

## Building Packages 

To build packages for the current API Umbrella version:

```sh
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella
$ make download_deps
$ make -j8 download_verify_package_deps
$ make -j8 all_packages # Adjust concurrency with -j flag as desired
```

Packages for each distribution will be created inside an isolated docker container, with the resulting packages being placed in the `build/package/dist` directory.

## Publishing Packages

To publish the new binary packages to our [BinTray repositories](https://bintray.com/nrel) (which provide yum and apt repos):

```sh
$ make publish_all_packages BINTRAY_USERNAME=username BINTRAY_API_KEY=api_key
```
