# Development Setup

The easiest way to get started with API Umbrella development is to use [Vagrant](http://www.vagrantup.com/) to setup a local development environment.

## Prerequisites

- 64bit CPU - the development VM requires an 64bit CPU on the host machine
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (version 4.3 or higher)
- [Vagrant](https://www.vagrantup.com/downloads.html) (version 1.6 or higher)
- [ChefDK](https://downloads.chef.io/chef-dk/) (version 0.10 or higher)
- NFS: For Mac OS X or Linux host machines only:
  - Mac OS X: Already installed and running
  - Ubuntu: `sudo apt-get install nfs-kernel-server nfs-common portmap`

## Setup

After installing VirtualBox and Vagrant, follow these steps:

```sh
# Install the required Vagrant plugins
$ vagrant plugin install vagrant-berkshelf

# Get the code and spinup your development VM
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella
$ vagrant up # This step compiles API Umbrella from source, so the first time
             # make take 30-40 minutes.
```

Assuming all goes smoothly, you should be able to see the homepage at [http://10.10.33.2/](http://10.10.33.2/).

If you run into issues when running `vagrant up`, try running `vagrant provision` once to see if the error reoccurs. This will pickup with the setup process from the last failure point, which can sometimes help resolve temporary issues.

If you're still having any difficulties getting the Vagrant environment setup, then open an [issue](https://github.com/NREL/api-umbrella/issues).

## Directory Structure

A quick overview of some of the relevant directories for development:

- `src/api-umbrella/cli`: The actions behind the `api-umbrella` command line tool.
- `src/api-umbrella/proxy`: The custom reverse proxy where API requests are validated before being allowed to the underlying API backend.
- `src/api-umbrella/web-app`: Provides the admin tool and APIs.
- `src/api-umbrella/web-app/spec`: Tests for the admin tool and APIs.
- `test`: Proxy tests and integration tests for the entire API Umbrella stack.

## Making Code Changes

This development VM runs the various components in "development" mode, which typically means any code changes you make will immediately be reflected. However, this does mean this development VM will run API Umbrella slower than in production.

While you can typically edit files and see your changes, for certain types of application changes, you may need to restart the server processes. There are two ways to restart things if needed:

```sh
# These commands must be executed *inside* your Vagrant VM:
$ vagrant ssh

# Quick: This should restart most server processes you'll need as a developer,
# but this doesn't restart everything:
$ sudo /etc/init.d/api-umbrella reload

# Slow: Restarts everything:
$ sudo /etc/init.d/api-umbrella restart
```

## Writing and Running Tests

See the [testing section](testing.html) for more information about writing and running tests.

## Customizing Your VM

The following environment variables can be set prior to running `vagrant up` if you wish to tune the local VM (for example, to give it more or less memory, pick a different IP address, or use a different base box):

```
API_UMBRELLA_VAGRANT_BOX=nrel/CentOS-6.7-x86_64
API_UMBRELLA_VAGRANT_MEMORY=2048
API_UMBRELLA_VAGRANT_CORES=2
API_UMBRELLA_VAGRANT_IP=10.10.33.2
API_UMBRELLA_VAGRANT_NFS=true
```
