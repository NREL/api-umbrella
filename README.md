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
* API Umbrella Web
  * [Ruby](http://www.ruby-lang.org/en/) (defaults to MRI Ruby 1.9)
  * [nginx](http://nginx.org/) (or your favorite web server)
  * [Phusion Passenger](http://www.modrails.com/) (or your favorite Rails application server)
  * [Elasticsearch](http://www.elasticsearch.org/)
  * [MongoDB](http://www.mongodb.org/)

Don't sweat this list, though—installation and configuration of everything can be automated through [Chef](http://www.opscode.com/chef/). See [Running API Umbrella](#running-api-umbrella) below for details.

## Running API Umbrella

The easiest way to get started with API Umbrella is to use [Vagrant](http://vagrantup.com/) to setup a local development environment.

First install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](http://vagrantup.com/) on your computer. Then follow these steps:

```sh
# Get the code
$ git clone https://github.com/NREL/api-umbrella.git
$ cd api-umbrella
$ git submodule update --init --recursive

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

## Using API Umbrella

Once you have API Umbrella up and running, there are a variety of things you can do to start using the platform. Here are some of the tasks

### Add APIs to the router

Out of the box, API Umbrella doesn't know about any APIs. You must first configure the URL endpoints you want proxied to APIs in the router.

In this example, we'll proxy to Google's Geocoding API (but you'll more likely be proxying to your own web services).

**Step 1:** Create `workspace/router/config/nginx/backends/google_apis.conf` with the following contents:

```
upstream google_apis_backend {
  server maps.googleapis.com:80;
  keepalive 10;
}
```

*This backend file defines the server or servers you want to route requests to. For more complex load-balancing configurations see [nginx's upstream documentation](http://wiki.nginx.org/HttpUpstreamModule) for more info.*

**Step 2:** Update `workspace/router/config/nginx/site.conf.erb` and add to the bottom inside the `server` block:

```
  # Insert your own...
  location ~* ^/google/ {
    rewrite ^/google(/.*) $1 break;
    proxy_set_header Host "maps.googleapis.com:80";

    # Enable keep alive connections to the backend servers.
    proxy_http_version 1.1;
    proxy_set_header Connection "";

    proxy_pass http://google_apis_backend;
  }
```

*This configuration defines which URL prefixes you wish to route to the new backend, and adjusts parts of the request when proxying occurs. See nginx's [proxy documentation](http://wiki.nginx.org/HttpProxyModule) and [location documentation](http://wiki.nginx.org/HttpCoreModule#location) for more info.* 

**Step 4:** Deploy your changes

```sh
$ vagrant ssh
$ cd /vagrant/workspace/router
$ cap vagrant deploy
```

### Signup for an API key

On your local environment, visit the signup form:

[http://localhost:8080/signup](http://localhost:8080/signup)

Signup to receive your own unique API key for your development environment.

### Make an API request

Assuming you added the Google Geocoding API example to your router config, you should now be able to make a request to Google's Geocoding API proxied through your local API Umbrella instance:

`http://localhost:8080/google/maps/api/geocode/json?address=Golden,+CO&sensor=false&api_key=**YOUR_KEY_HERE**`

You can see how API Umbrella layers its authentication on top of existing APIs by making a request using an invalid key:

[http://localhost:8080/google/maps/api/geocode/json?address=Golden,+CO&sensor=false&api_key=INVALID_KEY](http://localhost:8080/google/maps/api/geocode/json?address=Golden,+CO&sensor=false&api_key=INVALID_KEY)

### Login to the web admin

A web admin is available to perform basic tasks:

[http://localhost:8080/admin/](http://localhost:8080/admin/)

While in your local development environment, you may login with any name and e-mail address.

*This open admin is obviously not suitable for production, but alternative authentication mechanisms can be added via a variety of [OmniAuth strategies](https://github.com/intridea/omniauth/wiki/List-of-Strategies).*

### Write API documentation

Login to the [web admin](http://localhost:8080/admin/) and create documentation for individual web services and organize them into hierarchical collections. As documentation and collections are added, they will show up in the [documentation section](http://localhost:8080/doc) of the frontend.

## Deploying to Production

Migrating to other servers or a production environment can be largely handled by [Chef](http://www.opscode.com/chef/) and [Capistrano](http://capistranorb.com/):

1. Setup your servers using Chef and the available [cookbooks and roles](https://github.com/NREL/api-umbrella/tree/master/chef).
2. Deploy [api-umbrella-router](https://github.com/NREL/api-umbrella-router/tree/master) and [api-umbrella-web](https://github.com/NREL/api-umbrella-web/tree/master) with Capistrano: `cap production deploy`

## Who's using API Umbrella?

* [api.data.gov](http://api.data.gov/)
* [NREL Developer Network](http://developer.nrel.gov/)

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/9caf7fc8bb54ccd9e1670affa6b82618 "githalytics.com")](http://githalytics.com/NREL/api-umbrella)
