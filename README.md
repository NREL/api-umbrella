# API Umbrella

A platform for exposing web service APIs. The basic goal of API Umbrella is to make life easier for both API creators and API consumers. How?

* **Make life easier for API creators:** Allow API creators to focus on building APIs.
  * **Standardize the boring stuff:** APIs can assume the boring stuff (access control, rate limiting, analytics, etc.) is already taken care if the API is being accessed, so common functionality doesn't need to be implemented in the API code.
  * **Easy to add:** API Umbrella acts as a layer above your APIs, so your API code doesn't need to be modified to take advantage of the features provided.
  * **Scalability:** Make it easier to scale your APIs.
* **Make life easier for API consumers:** Let API consumers easily explore and use your APIs.
  * **Unify disparate APIs:** Present separate APIs as a cohesive offering to API consumers. APIs running on different servers or written in different programming languages can be exposed at a single endpoint for the API consumer.
  * **Standardize access:** All your APIs are can be accessed using the same API key credentials. 
  * **Standardize documentation:** All your APIs are documented in a single place and in a similar fashion. 

API Umbrella is broken into several components:

* **[API Umbrella Gatekeeper](https://github.com/NREL/api-umbrella-gatekeeper):** A custom reverse proxy to control access to your APIs. Performs API key validation, request rate limiting, and gathers analytics.
* **[API Umbrella Router](https://github.com/NREL/api-umbrella-router/tree/master):** Combines reverse proxies (API Umbrella Gatekeeper and HAProxy) to route requests to the appropriate backend. Ensures all API requests are approved by the gatekeeper and gives the appearance of unified APIs.
* **[API Umbrella Web](https://github.com/NREL/api-umbrella-web):** A web application for providing API documentation and API key signup.
