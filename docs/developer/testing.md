# Testing

## Test Suite

API Umbrella's test suite uses Ruby's [minitest](https://github.com/seattlerb/minitest). All tests are located in the [`test`](https://github.com/NREL/api-umbrella/tree/master/test) directory. Tests are separated into these areas:

- [`test/admin_ui`](https://github.com/NREL/api-umbrella/tree/master/test/admin_ui): Browser-based tests for the `admin-ui` component using [Capybara](http://teamcapybara.github.io/capybara/).
- [`test/apis`](https://github.com/NREL/api-umbrella/tree/master/test/apis): HTTP tests for the internal APIs provided by API Umbrella.
- [`test/processes`](https://github.com/NREL/api-umbrella/tree/master/test/processes): Testing the behavior of API Umbrella's server processes.
- [`test/proxy`](https://github.com/NREL/api-umbrella/tree/master/test/proxy): Testing the behavior of API Umbrella's proxy features.
- [`test/testing_sanity_checks`](https://github.com/NREL/api-umbrella/tree/master/test/testing_sanity_checks): Tests to sanity check certain behaviors of the overall test suite.

## Running Tests

Assuming you have a [Vagrant development environment](dev-setup.html), you can run all the tests with:

```sh
$ cd /vagrant
$ make test
```

### Running Individual Tests

If you'd like to run individual tests, rather than all the tests, there are a few different ways to do that:

```sh
# Run individual files or tests within the web-app test suite:
$ cd /vagrant
$ ruby test/apis/v1/admins/test_create.rb
```
