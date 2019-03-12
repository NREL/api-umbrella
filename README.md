[![CircleCI](https://circleci.com/gh/NREL/api-umbrella.svg?style=svg)](https://circleci.com/gh/NREL/api-umbrella) [![Dependency Status](https://gemnasium.com/badges/github.com/NREL/api-umbrella.svg)](https://gemnasium.com/github.com/NREL/api-umbrella)

# APInf Umbrella

## What Is APInf Umbrella?

APInf Umbrella is an open source API management platform (forked from NREL api umbrella) for exposing web service APIs. The basic goal of API Umbrella is to make life easier for both API creators and API consumers. How?

* **Easy integration:** APInf Umbrella is integrated with APInf platform. It also has additional features, like IDM integration (keyrock)

* **Make life easier for API creators:** Allow API creators to focus on building APIs.
  * **Standardize the boring stuff:** APIs can assume the boring stuff (access control, rate limiting, analytics, etc.) is already taken care if the API is being accessed, so common functionality doesn't need to be implemented in the API code.
  * **Easy to add:** API Umbrella acts as a layer above your APIs, so your API code doesn't need to be modified to take advantage of the features provided.
  * **Scalability:** Make it easier to scale your APIs.
* **Make life easier for API consumers:** Let API consumers easily explore and use your APIs.
  * **Unify disparate APIs:** Present separate APIs as a cohesive offering to API consumers. APIs running on different servers or written in different programming languages can be exposed at a single endpoint for the API consumer.
  * **Standardize access:** All your APIs are can be accessed using the same API key or OAuth credentials.
  * **Standardize documentation:** All your APIs are documented in a single place and in a similar fashion.

## Getting Started

We are updating documentation. Please see [Installation] in APInf platform documentation (https://github.com/apinf/platform/blob/develop/INSTALL.md)

## License

APInf Umbrella is open sourced under the [MIT license](https://github.com/apinf/api-umbrella/blob/master/LICENSE.txt).
