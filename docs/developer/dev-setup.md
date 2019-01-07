# Development Setup

The easiest way to get started with API Umbrella development is to use [Docker](https://www.docker.com) to setup a local development environment.

## Prerequisites

- 64bit CPU - the development VM requires an 64bit CPU on the host machine
- [Docker](https://www.docker.com/get-started)

## Setup

After installing Docker, follow these steps:

```sh
# Get the code and spinup your development VM
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella
$ docker-compose up
```

Assuming all goes smoothly, you should be able to see the homepage at [https://localhost:8101/](https://localhost:8101/). You will need to need to accept the self-signed SSL certificate for localhost in order to access the development environment.

If you're having any difficulties getting the development environment setup, then open an [issue](https://github.com/NREL/api-umbrella/issues).

## Directory Structure

A quick overview of some of the relevant directories for development:

- `src/api-umbrella/admin-ui`: The admin user interface which utilizes the administrative APIs provided by the web-app.
- `src/api-umbrella/cli`: The actions behind the `api-umbrella` command line tool.
- `src/api-umbrella/proxy`: The custom reverse proxy where API requests are validated before being allowed to the underlying API backend.
- `src/api-umbrella/web-app`: Provides the public and administrative APIs.
- `test`: Proxy tests and integration tests for the entire API Umbrella stack.

## Making Code Changes

This development environment runs the various components in "development" mode, which typically means any code changes you make will immediately be reflected. However, this does mean this development environment will run API Umbrella slower than in production.

While you can typically edit files and see your changes, for certain types of application changes, you may need to restart the server processes. There are two ways to restart things if needed:

```sh
# Quick: Reload most server processes by executing a reload command:
docker-compose exec app api-umbrella reload

# Slow: Fully restart everything:
docker-compose stop
docker-compose up
```

## Writing and Running Tests

See the [testing section](testing.html) for more information about writing and running tests.
