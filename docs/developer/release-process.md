# Release Process

Some basic instructions to follow when releasing a new, stable version of API Umbrella.

- Update the version number in [`src/api-umbrella/version.txt`](https://github.com/NREL/api-umbrella/blob/master/src/api-umbrella/version.txt)
  - Use [semantic versioning](http://semver.org).
- Update [CHANGELOG.md](https://github.com/NREL/api-umbrella/blob/master/CHANGELOG.md) with release notes.
- Update other references to the version number:
  - Documentation:
    - [`docs/conf.py`](https://github.com/NREL/api-umbrella/blob/master/docs/conf.py)
    - [`docs/developer/compiling-from-source.md`](https://github.com/NREL/api-umbrella/blob/master/docs/developer/compiling-from-source.md)
  - Website:
    - [`website/source/index.html.erb`](https://github.com/NREL/api-umbrella/blob/master/website/source/index.html.erb)
    - [`website/source/install.html.erb`](https://github.com/NREL/api-umbrella/blob/master/website/source/install.html.erb)
  - [`Dockerfile`](https://github.com/NREL/api-umbrella/blob/master/docker/Dockerfile)
- Build and publish new [binary packages](packaging.html).
- Build and publish new [docker container](docker-build.html).
- Add a new [GitHub Release](https://github.com/NREL/api-umbrella/releases) (use the same release notes from the CHANGELOG).
