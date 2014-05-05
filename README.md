# API Umbrella

## What Is API Umbrella?

API Umbrella is an open source API management platform for exposing web service APIs. The basic goal of API Umbrella is to make life easier for both API creators and API consumers. How?

* **Make life easier for API creators:** Allow API creators to focus on building APIs.
  * **Standardize the boring stuff:** APIs can assume the boring stuff (access control, rate limiting, analytics, etc.) is already taken care if the API is being accessed, so common functionality doesn't need to be implemented in the API code.
  * **Easy to add:** API Umbrella acts as a layer above your APIs, so your API code doesn't need to be modified to take advantage of the features provided.
  * **Scalability:** Make it easier to scale your APIs.
* **Make life easier for API consumers:** Let API consumers easily explore and use your APIs.
  * **Unify disparate APIs:** Present separate APIs as a cohesive offering to API consumers. APIs running on different servers or written in different programming languages can be exposed at a single endpoint for the API consumer.
  * **Standardize access:** All your APIs are can be accessed using the same API key credentials.
  * **Standardize documentation:** All your APIs are documented in a single place and in a similar fashion.

## Components

API Umbrella is broken into several components:

* **[API Umbrella Gatekeeper](https://github.com/NREL/api-umbrella-gatekeeper):** A custom reverse proxy to control access to your APIs. Performs API key validation, request rate limiting, and gathers analytics.
* **[API Umbrella Router](https://github.com/NREL/api-umbrella-router/tree/master):** Combines reverse proxies (API Umbrella Gatekeeper and nginx) to route requests to the appropriate backend. Ensures all API requests are approved by the gatekeeper and gives the appearance of unified APIs.
* **[API Umbrella Web](https://github.com/NREL/api-umbrella-web/tree/master):** A web application for providing API documentation and API key signup. Also provides the admin interface for managing documentation, users, and viewing analytics.

## Dependencies

* API Umbrella Gatekeeper
  * [Node.js](http://nodejs.org/)
  * [Redis](http://redis.io/)
  * [Elasticsearch](http://www.elasticsearch.org/)
  * [MongoDB](http://www.mongodb.org/)
  * [Supervisor](http://supervisord.org/)
* API Umbrella Router
  * [nginx](http://nginx.org/)
  * [Varnish](http://varnish-cache.org)
* API Umbrella Web
  * [Ruby](http://www.ruby-lang.org/en/) (defaults to MRI Ruby 1.9)
  * [nginx](http://nginx.org/) (or your favorite web server)
  * [Phusion Passenger](http://www.modrails.com/) (or your favorite Rails application server)
  * [Elasticsearch](http://www.elasticsearch.org/)
  * [MongoDB](http://www.mongodb.org/)

Don't sweat this list, though—installation and configuration of everything can be automated through [Chef](http://www.opscode.com/chef/). See [Running API Umbrella](#running-api-umbrella) below for details.

## Running API Umbrella

The easiest way to get started with API Umbrella is to use [Vagrant](http://vagrantup.com/) to setup a local development environment.

First install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](http://vagrantup.com/) (version 1.5 or higher) on your computer. Then follow these steps:

```sh
# Install the Vagrant Berkshelf plugin (version 2.0.1 or higher).
$ vagrant plugin install vagrant-berkshelf --plugin-version '>= 2.0.1'

# Get the code
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella
$ git submodule update --init --recursive

# Add api.vagrant to your hosts file.
$ sudo sh -c 'echo "10.10.10.2 api.vagrant" >> /etc/hosts'

# Bootstrap a local VM environment (this will take a while)
$ vagrant up

# Login to your local VM
$ vagrant ssh

# Setup the apps on your local VM
$ cd /vagrant/workspace/router
$ bundle install --path=/srv/sites/router/shared/vendor/bundle
$ cap vagrant deploy

$ cd /vagrant/workspace/web
$ cp config/mongoid.yml.deploy config/mongoid.yml && cp config/elasticsearch.yml.deploy config/elasticsearch.yml
$ bundle install --path=/srv/sites/web/shared/vendor/bundle
$ cap vagrant deploy

# Tada?
```

Assuming all that goes smoothly, you should be able see the homepage at [http://localhost:8080/](http://localhost:8080/)

Problems? Open an [issue](https://github.com/NREL/api-umbrella/issues).

## Getting Started

Once you have API Umbrella up and running, there are a variety of things you can do to start using the platform. For a quick tutorial see [getting started](https://github.com/NREL/api-umbrella/blob/master/docs/GettingStarted.md).

## Deploying to Production

Migrating to other servers or a production environment can be largely handled by [Chef](http://www.opscode.com/chef/) and [Capistrano](http://capistranorb.com/):

1. Setup your servers using Chef and the available [cookbooks and roles](https://github.com/NREL/api-umbrella/tree/master/chef).
2. Deploy [api-umbrella-router](https://github.com/NREL/api-umbrella-router/tree/master) and [api-umbrella-web](https://github.com/NREL/api-umbrella-web/tree/master) with Capistrano: `cap production deploy`

## Who's using API Umbrella?

* [api.data.gov](http://api.data.gov/)
* [NREL Developer Network](http://developer.nrel.gov/)

Are you using API Umbrella? Open an issue and let us know.

## License

API Umbrella is open sourced under the [MIT license](https://github.com/NREL/api-umbrella/blob/master/LICENSE.txt).

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/9caf7fc8bb54ccd9e1670affa6b82618 "githalytics.com")](http://githalytics.com/NREL/api-umbrella)
