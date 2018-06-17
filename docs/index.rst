API Umbrella Documentation
========================================

What Is API Umbrella?
---------------------

API Umbrella is an open source API management platform for exposing web service APIs. The basic goal of API Umbrella is to make life easier for both API creators and API consumers. How?

- **Make life easier for API creators:** Allow API creators to focus on building APIs.

  - **Standardize the boring stuff:** APIs can assume the boring stuff (access control, rate limiting, analytics, etc.) is already taken care if the API is being accessed, so common functionality doesn't need to be implemented in the API code.
  - **Easy to add:** API Umbrella acts as a layer above your APIs, so your API code doesn't need to be modified to take advantage of the features provided.
  - **Scalability:** Make it easier to scale your APIs.

- **Make life easier for API consumers:** Let API consumers easily explore and use your APIs.

  - **Unify disparate APIs:** Present separate APIs as a cohesive offering to API consumers. APIs running on different servers or written in different programming languages can be exposed at a single endpoint for the API consumer.
  - **Standardize access:** All your APIs are can be accessed using the same API key credentials.
  - **Standardize documentation:** All your APIs are documented in a single place and in a similar fashion.

.. toctree::
   :caption: Getting Started
   :maxdepth: 1

   getting-started

.. toctree::
   :caption: For Admin Users
   :maxdepth: 2

   admin/api-backends/index
   admin/api-users/index
   admin/admin-accounts/index
   admin/analytics/index
   admin/website-backends
   admin/api
   admin/other-docs

.. toctree::
   :caption: For System Admins
   :maxdepth: 1

   server/admin-auth
   server/https-config
   server/smtp-config
   server/multi-server
   server/listen-ports
   server/logs
   server/db-config

.. toctree::
   :caption: For API Consumers
   :maxdepth: 1

   api-consumer/api-key-usage
   api-consumer/rate-limits

.. toctree::
   :caption: For API Umbrella Developers
   :maxdepth: 1

   developer/architecture
   developer/dev-setup
   developer/testing
   developer/deploying
   developer/packaging
   developer/docker-build
   developer/compiling-from-source
   developer/release-process
   developer/analytics-architecture
