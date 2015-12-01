# Building Docker Images

## Prerequisites

- git
- Docker

## Building Images

To build packages for the current API Umbrella version:

```sh
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella/docker
$ docker build -t nrel/api-umbrella:INSERT_VERSION_HERE .
$ docker tag nrel/api-umbrella:INSERT_VERSION_HERE nrel/api-umbrella:latest
```

## Pushing to Docker Hub

To publish the new images to our [Docker Hub repository](https://hub.docker.com/r/nrel/api-umbrella/):

```sh
$ docker push nrel/api-umbrella:INSERT_VERSION_HERE
$ docker push nrel/api-umbrella:latest
```
