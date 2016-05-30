# Testing

## Test Suites

There are two main test suites for API Umbrella located in the following directories:

- [`test`](https://github.com/NREL/api-umbrella/tree/master/test): Tests for the proxy component of API Umbrella, as well as integration tests for the entire stack. These tests are written in NodeJS using [Mocha](https://mochajs.org) and [Chai](http://chaijs.com).
- [`src/api-umbrella/web-app/spec`](https://github.com/NREL/api-umbrella/tree/master/src/api-umbrella/web-app/spec): Tests for the web-app Rails component of API Umbrella, which provides the admin APIs and admin UI. These tests are written in Ruby using [RSpec](http://rspec.info).

## Running Tests

Assuming you have a [Vagrant development environment](dev-setup.html), you can run all the tests (from both test suites) with:

```sh
$ cd /vagrant
$ make test
```

### Running Individual Tests

If you'd like to run individual tests, rather than all the tests, there are a few different ways to do that:

```sh
# Run the entire proxy test suite: 
$ make test-proxy

# Run the entire web-app test suite:
$ make test-web-app

# Run individual files or tests within the proxy test suite:
$ cd test
./node_modules/.bin/grunt ./server/api_matcher.js

# Run individual files or tests within the web-app test suite:
$ cd src/api-umbrella/web-app
$ bundle exec rspec ./spec/controllers/api/v1/apis_controller_spec.rb
```
