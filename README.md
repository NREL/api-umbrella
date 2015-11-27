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

## Download

Binary packages are available for [download](http://nrel.github.io/api-umbrella/download/). Follow the quick setup instructions on the download page to begin running API Umbrella.

## Getting Started

Once you have API Umbrella up and running, there are a variety of things you can do to start using the platform. For a quick tutorial, see [getting started](http://nrel.github.io/api-umbrella/docs/getting-started/).

## API Umbrella Development

Are you interested in working on the code behind API Umbrella? See our [development setup guide](http://nrel.github.io/api-umbrella/docs/development-setup/) to see how you can get a local development environment setup.

## Projects

In addition to this project, API Umbrella is made up of the following subprojects:

* [api-umbrella-gatekeeper](https://github.com/NREL/api-umbrella-gatekeeper) - The gatekeeper is a custom reverse proxy that sits in front of your APIs and efficiently validates incoming requests.
* [api-umbrella-router](https://github.com/NREL/api-umbrella-router) - The router provides the necessary configuration to join together API Umbrealla Gatekeeper with other open source proxies.
* [api-umbrella-web](https://github.com/NREL/api-umbrella-web) - The web component provides the website frontend and web admin tool.
* [api-umbrella-static-site](https://github.com/NREL/api-umbrella-static-site) - The static site provides the public website content using a static site generator.
* [api-umbrella-config](https://github.com/NREL/api-umbrella-config) - Provides configuration file parsing for the other API Umbrella components.
* [omnibus-api-umbrella](https://github.com/NREL/omnibus-api-umbrella) - Omnibus packaging for API Umbrella

## Who's using API Umbrella?

* [api.data.gov](http://api.data.gov/)
* [NREL Developer Network](http://developer.nrel.gov/)

Are you using API Umbrella? [Edit this file](https://github.com/NREL/api-umbrella/blob/master/README.md) and let us know.

## License

API Umbrella is open sourced under the [MIT license](https://github.com/NREL/api-umbrella/blob/master/LICENSE.txt).
