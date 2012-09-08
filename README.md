# API Umbrella

## What Is API Umbrella?

API Umbrella is a platform for exposing web service APIs. The basic goal of API Umbrella is to make life easier for both API creators and API consumers. How?

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
* **[API Umbrella Router](https://github.com/NREL/api-umbrella-router/tree/master):** Combines reverse proxies (API Umbrella Gatekeeper and HAProxy) to route requests to the appropriate backend. Ensures all API requests are approved by the gatekeeper and gives the appearance of unified APIs.
* **[API Umbrella Web](https://github.com/NREL/api-umbrella-web):** A web application for providing API documentation and API key signup.

## Dependencies

* [HAProxy](http://haproxy.1wt.eu/)
* [MongoDB](http://www.mongodb.org/)
* [nginx](http://nginx.org/) (or your favorite web server)
* [Phusion Passenger](http://www.modrails.com/) (or your favorite Rails application server)
* [Redis](http://redis.io/)
* [Ruby](http://www.ruby-lang.org/en/) (currently only supports MRI Ruby 1.9, but hopefully JRuby soon)
* [Supervisor](http://supervisord.org/)

Don't sweat this list, though—installation and configuration of everything can be automated through [Chef](http://www.opscode.com/chef/). See [Running API Umbrella](#running-api-umbrella) below for details.

## Running API Umbrella

The easiest way to get started with API Umbrella is to use [Vagrant](http://vagrantup.com/) to setup a local development environment.

First install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](http://vagrantup.com/) on your computer. Then:

```sh
# Get the code
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella
$ git submodule init
$ git submodule update

# Bootstrap a local VM environment (this will take a while)
$ vagrant up

# Login to your local VM
$ vagrant ssh

# Setup the apps on your local VM
$ cd /vagrant/workspace/api-umbrella-router
$ cp config/mongoid.yml.example config/mongoid.yml && cp config/redis.yml.example config/redis.yml
$ bundle install --path=vendor/bundle
$ cap vagrant deploy

$ cd /vagrant/workspace/api-umbrella-web
$ cp config/mongoid.yml.example config/mongoid.yml
$ bundle install --path=vendor/bundle
$ cap vagrant deploy

# Tada?
```

Assuming all that goes smoothly, you should be able see the homepage at [http://localhost:8274/](http://localhost:8274/)

Problems? Open an [issue](https://github.com/NREL/api-umbrella/issues).

### Setting Up Production Servers

Migrating to other servers or a production environment can be largely handled by [Chef](http://www.opscode.com/chef/) and [Capistrano](http://capistranorb.com/):

1. Setup your servers using Chef and the available [cookbooks and roles](https://github.com/NREL/api-umbrella/tree/master/chef).
2. Deploy [api-umbrella-router](https://github.com/NREL/api-umbrella-router/tree/master) and [api-umbrella-web](https://github.com/NREL/api-umbrella-web) with Capistrano: `cap production deploy`

## Who's using API Umbrella?

* [NREL Developer Network](http://developer.nrel.gov/)
