# API Umbrella Change Log

## 0.7.1 / 2015-02-11

This update fixes a couple of important bugs that were discovered shortly after rolling out the v0.7.0 release. It's highly recommended anyone running v0.7.0 upgrade to v0.7.1.

[Download 0.7.1 Packages](http://nrel.github.io/api-umbrella/download/)

### Upgrade Instructions

If you're upgrading a previous API Umbrella version, you must first stop API Umbrella manually (`sudo /etc/init.d/api-umbrella stop`) before installing the new package. 

### Changes

* Fix 502 Bad Gateway errors for newly published API backends. Due to the DNS changes introduced in v0.7.0, newly published API backends may have not have properly resolved and passed traffic to the backend servers. (See [#107](https://github.com/NREL/api-umbrella/issues/107))
* Fix broken admin for non-English web browsers. The translations we introduced in v0.7.0 should actually now work (whoops!). (See [#103](https://github.com/NREL/api-umbrella/issues/103))
* Cut down on unnecessary DNS changes triggering reloads.
* Adjust internal API Umbrella logging to reduce error and warning log messages for expected events.
* Disables Groovy scripting in default ElasticSearch setup due to [CVE-2015-1427](http://www.elasticsearch.org/blog/elasticsearch-1-4-3-and-1-3-8-released/).

## 0.7.0 / 2015-02-08

[Download 0.7.0 Packages](http://nrel.github.io/api-umbrella/download/)

### Upgrade Instructions

If you're upgrading from API Umbrella v0.6.0, you must first stop API Umbrella manually (`sudo /etc/init.d/api-umbrella stop`) before installing the new package. 

### Highlights

* **Admin UI Improvements:** Lots of tweaks and fixes have been made to the various parts of the admin to make it easier to use. There are better defaults, better notifications, and a lot more error validations to make it easier to manage API backends and users. (Related: [api.data.gov#160](https://github.com/18F/api.data.gov/issues/160), [api.data.gov#158](https://github.com/18F/api.data.gov/issues/158), [#49](https://github.com/NREL/api-umbrella/issues/49))
* **Improved DNS handling for API backends:** Fixes edge-case scenarios where DNS lookups may have not refreshed too quickly for backend API domain names with short TTLs (typically affecting API backends hosted behind Heroku, Akamai, or an Amazon Elastic Load Balancer). In certain rare cases, this could have temporarily taken down an API. (Related: [api.data.gov#131](https://github.com/18F/api.data.gov/issues/131))
* **Improved analytics gathering:** Fixes edge-case scenarios where analytics logs may have not been gathered. Request logs should also now show up in the admin analytics more quickly (within a few seconds). (Related: [#37](https://github.com/NREL/api-umbrella/issues/37), [api.data.gov#138](https://github.com/18F/api.data.gov/issues/138), [api.data.gov#106](https://github.com/18F/api.data.gov/issues/106))
* **Improved server startup:** Lots of fixes for various startup issues that should make starting API Umbrella more reliable on all platforms. API Umbrella v0.6 was our first package release across multiple platforms, so thanks to everyone in the community for reporting issues, and apologies if things were a bit bumpy. Hopefully v0.7 should be a bit easier to get running for everyone, but please let us know if not. (Related: [#42](https://github.com/NREL/api-umbrella/issues/42), [#89](https://github.com/NREL/api-umbrella/issues/89), [#92](https://github.com/NREL/api-umbrella/issues/92), [#100](https://github.com/NREL/api-umbrella/issues/100)
* **Dyanmic HTTP header rewriting:** Thanks to [@darylrobbins](https://github.com/darylrobbins) for this new feature, you can now perform more complex header rewriting by referencing existing header values during the HTTP header rewriting phase. (Related: [#96](https://github.com/NREL/api-umbrella/issues/96), [api-umbrella-gatekeeper#7](https://github.com/NREL/api-umbrella-gatekeeper/pull/7))
* **Admin Internationalization:** We've begun work to allow the admin interface to be translated into other languages. This is still incomplete, but the main admin menus and a good portion of the API Backends screen should now be available in Finnish, French, Italian, and Russian (with some translations started in German and Spanish too). Many thanks to [@perfaram](https://github.com/perfaram), [@kyyberi](https://github.com/kyyberi), Vesa Härkönen, vpilo, and enizev! (Related: [#60](https://github.com/NREL/api-umbrella/issues/60)) 

### Everything Else

* Fix analytics CSV downloads. (Related: [api.data.gov#173](https://github.com/18F/api.data.gov/issues/173))
* Fix default API key signup form in IE8-9. (Related [api.data.gov#174](https://github.com/18F/api.data.gov/issues/174))
* Give a better error message to restricted admins when they try to create an API outside of their permission scope. (Related: [api.data.gov#152](https://github.com/18F/api.data.gov/issues/152))
* Improve the admin UI for publishing backend changes to provide more sane checkbox defaults. (Related: [api.data.gov#169](https://github.com/18F/api.data.gov/issues/169))
* Treat admin logins case insensitively. (Related [api.data.gov#170](https://github.com/18F/api.data.gov/issues/170))
* Fix bugs preventing the GitHub OAuth based logins for admins from working. (Related: [#46](https://github.com/NREL/api-umbrella/issues/46), [#88](https://github.com/NREL/api-umbrella/issues/88))
* Fix limited admin account not having privileges to assign the special "api-umbrella-key-creator" role. (Related: [api.data.gov#157](https://github.com/18F/api.data.gov/issues/157))
* Fix analytics permissions for restricted admins for API paths containing uppercase characters. (Related: [api.data.gov#154](https://github.com/18F/api.data.gov/issues/154))
* Fix admin permissions for API backends with multiple URL prefixes. (Related: [api.data.gov#156](https://github.com/18F/api.data.gov/issues/156))
* Increase the default number of concurrent HTTP connections the various processes can accept.
* Fix inability to unset referrer or IP restrictions on user accounts once set. (Related [#97](https://github.com/NREL/api-umbrella/issues/97), [api.data.gov#155](https://github.com/18F/api.data.gov/issues/155))
* Fix issues surrounding default log rotation setup
* Retry connections to MongoDB in the event of MongoDB disconnects.
* Add the ability to selectively reload API Umbrella components via the `api-umbrella reload` command.
* Add a [deployment process](http://nrel.github.io/api-umbrella/docs/deployment/) for deploying non-packaged updates for API Umbrella components directly from git. (Related: [api.data.gov#159](https://github.com/18F/api.data.gov/issues/159), [api.data.gov#161](https://github.com/18F/api.data.gov/issues/161), [#99](https://github.com/NREL/api-umbrella/issues/99))
* Upgrade bundled dependencies
  * Bundler 1.7.4 -> 1.7.12
  * ElasticSearch 1.3.4 -> 1.4.2
  * MongoDB 2.6.5 -> 2.6.7
  * nginx 1.7.6 -> 1.7.9
  * Node.js 0.10.33 -> 0.10.36
  * OpenSSL 1.0.1j -> 1.0.1l
  * Redis 2.8.17 -> 2.8.19
  * Ruby 2.1.3 -> 2.1.5
  * RubyGems 2.4.2 -> 2.4.5
  * Ruby on Rails 3.2.19 -> 3.2.21
  * Supervisor 3.1.2 -> 3.1.3

## 0.6.0 / 2014-10-27

* Initial package releases for CentOS, Debian, and Ubuntu.
