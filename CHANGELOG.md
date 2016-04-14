# API Umbrella Change Log

## 0.11.1 (2016-04-14)

This is a small update that fixes a couple bugs (one important one if you use the HTTP cache), makes a couple small tweaks, and updates some dependencies for security purposes. Upgrading is recommended.

### Upgrade Instructions

If you're upgrading a previous API Umbrella version, you may upgrade the `api-umbrella` package using your package manager.

### Changed

* **Upgrade bundled software dependencies:**
  * OpenResty 1.9.7.1 -> 1.9.7.4 (Security updates: CVE-2016-0742, CVE-2016-0746, and CVE-2016-0747)
  * Rails 3.2.22 -> 3.2.22.2 (Security updates: CVE-2015-7576, CVE-2016-0751, CVE-2015-7577, CVE-2016-0752, CVE-2016-0753, CVE-2015-7581, CVE-2016-2097, and CVE-2016-2098)
  * Rebuild Mora and Heka with Go 1.5.4 (Security update: CVE-2016-3959)
* **Remove empty "Dashboard" link from the admin:** The "Dashboard" link has never had any content, so we've removed it from the admin navigation. ([api.data.gov#323](https://github.com/18F/api.data.gov/issues/323))
* **Make the optional public metrics API more configurable:** If enabled, the public metrics API's filters are now more easily configurable. ([api.data.gov#313](https://github.com/18F/api.data.gov/issues/313))

### Fixed

* **Resolve possible HTTP cache conflicts:** If API Umbrella is configured with multiple API backends that utilize the same frontend host and same backend URL path prefix, then if either API backend returned cacheable responses, then it's possible the responses would get mixed up. Upgrading is highly recommended if you utilize the HTTP cache and have multiple API backends utilizing the same URL path prefix. ([api.data.gov#322](https://github.com/18F/api.data.gov/issues/322))
* **Don't require API key roles for accessing admin APIs if admin token is used:** If accessing the administrative APIs using an admin authentication token, then the API key no longer needs any special roles assigned. This was a regression that ocurred in API Umbrella v0.9.0. ([#217](https://github.com/NREL/api-umbrella/issues/217))
* **Fix potential mail security issue:** OSVDB-131677.

## 0.11.0 (2016-01-20)

This is a small update that fixes a few bugs, adds a couple small new features, and updates some dependencies for security purposes. Upgrading is recommended.

### Upgrade Instructions

If you're upgrading a previous API Umbrella version, you may upgrade the `api-umbrella` package using your package manager.

### Added

* **Search user role names in admin user search:** In the admin search interface for users, role names assigned to users are now searched too. ([api.data.gov#302](https://github.com/18F/api.data.gov/issues/302))
* **Allow for nginx's `server_names_hash_bucket_size` option to be set:** If you've explicitly defined `hosts` in the API Umbrella config with longer hostnames, you can now adjust the `nginx.server_names_hash_bucket_size` setting in `/etc/api-umbrella/api-umbrella.yml` to accommodate longer hostnames. ([#208](https://github.com/NREL/api-umbrella/issues/208))
* **Documentation on MongoDB authentication:** Add [documentation](http://api-umbrella.readthedocs.org/en/latest/server/db-config.html#mongodb-authentication) on configuring API Umbrella to use a MongoDB server with authentication.  ([#206](https://github.com/NREL/api-umbrella/issues/206))

### Changed

* **Upgrade bundled software dependencies:**
  * Elasticsearch 1.7.3 -> 1.7.4
  * MongoDB 3.0.7 -> 3.0.8
  * OpenResty 1.9.3.2 -> 1.9.7.1
  * Ruby 2.2.3 -> 2.2.4

### Fixed

* **Fix editing users with custom rate limits:** There were a few bugs related to editing custom rate limits on users that broke in the v0.9 release. ([api.data.gov#303](https://github.com/18F/api.data.gov/issues/303), [api.data.gov#304](https://github.com/18F/api.data.gov/issues/304), [api.data.gov#306](https://github.com/18F/api.data.gov/issues/306))
* **Fix MongoDB connections when additional options are given:** If the `mongodb.url` setting contained additional query string options, it could cause connection failures. ([#206](https://github.com/NREL/api-umbrella/issues/206))
* **Fix logging requests containing multiple `User-Agent` headers:** If a request contained multiple `User-Agent` HTTP headers, the request would fail to be logged to the analytics database. ([api.data.gov#309](https://github.com/18F/api.data.gov/issues/309))
* **Raise default resource limits when starting processes:** Restore functionality that went missing in the v0.9 release that raised the `nofile` and `noproc` resource limits to a configurable number.

### Security

We've updated several dependencies with reported security issues. We're not aware of these security issues impacting API Umbrella in any significant way, but upgrading is still recommended.

* Update bundled Ruby to 2.2.4 ([CVE-2015-7551](https://www.ruby-lang.org/en/news/2015/12/16/unsafe-tainted-string-usage-in-fiddle-and-dl-cve-2015-7551/))
* Recompiled Go dependencies with Go 1.5.3 ([CVE-2015-8618](https://groups.google.com/forum/#!topic/golang-announce/MEATuOi_ei4))
* Updated Gem dependencies with reported vulnerabilities:
  * jquery-rails ([CVE-2015-1840](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2015-1840))
  * mail ([OSVDB-131677](http://rubysec.com/advisories/OSVDB-131677/))
  * net-ldap ([OSVDB-106108](http://osvdb.org/show/osvdb/106108))
  * nokogiri ([CVE-2015-5312](https://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2015-5312), [CVE-2015-7499](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2015-7499))

## 0.10.0 (2015-12-15)

This is a small update that fixes a few bugs and adds a couple small new features.

### Upgrade Instructions

If you're upgrading a previous API Umbrella version, you may upgrade the `api-umbrella` using your package manager.

### Added

* **Make additional fields visible in the admin analytics:** The HTTP referer, Origin header, user agent family, and user agent type fields are now visible in analytics views for individual requests. ([#201](https://github.com/NREL/api-umbrella/issues/201))
* **Show version number in admin:** In the admin footer, the current API Umbrella version number is now displayed. ([#169](https://github.com/NREL/api-umbrella/issues/169))

### Fixed

* **Fixes to packages:** Various fixes and improvements to the `.rpm` and `.deb` packages to allow for easier package upgrades. ([#200](https://github.com/NREL/api-umbrella/issues/200))
* **Fix CSV downloads of admin analytics reports:** The CSV downloads of the Filter Logs results in the analytics admin was broken in the v0.9 release ([api.data.gov#298](https://github.com/18F/api.data.gov/issues/298))
* **Fix admin issues with admin groups and roles:** Admin groups management and role auto-completion were both broken in the v0.9 release ([api.data.gov#299](https://github.com/18F/api.data.gov/issues/299))
* **Better service start/stop error handling:** Better error messages if the trying to start the service when already started or stop the service when already stopped. ([#203](https://github.com/NREL/api-umbrella/issues/203))

## 0.9.0 (2015-11-27)

This is a significant upgrade to API Umbrella's internals, but should be backwards compatible with previous installations. It should be faster, more efficient, and more resilient, so upgrading is recommended.

### Upgrade Instructions

If you're upgrading a previous API Umbrella version, you must first stop API Umbrella manually (`sudo /etc/init.d/api-umbrella stop`) before installing the new package.

### Highlights

* **Internal rewrite:** The core API Umbrella proxy functionality has been rewritten in Lua embedded inside nginx. This simplifies the codebase, brings better performance, and reduces system requirements. (See [#86](https://github.com/NREL/api-umbrella/issues/86) and [#183](https://github.com/NREL/api-umbrella/pull/183))
* **Improved analytics logging:** Analytics logging is now faster. If a backlog occurs in logging requests, memory usage no longer grows. (See [api.data.gov#233](https://github.com/18F/api.data.gov/issues/233))
* **Resiliency:** API Umbrella caches some data locally so it can continue to operate even if the databases behind the scenes temporarily fail. (See [#183](https://github.com/NREL/api-umbrella/pull/183))
* **CLI improvements:** The `api-umbrella` CLI tool should be better behaved at starting and stopping all the processes as expected. Reloads should always pickup config file changes (See [#183](https://github.com/NREL/api-umbrella/pull/183) and [api.data.gov#221](https://github.com/18F/api.data.gov/issues/221))
* **Packaging improvements:** Binary packages are now available via apt or yum repos for easier installation (See [#183](https://github.com/NREL/api-umbrella/pull/183))
* **DNS and keep-alive improvements:** How API Umbrella detects DNS changes in backend hosts has been simplified and improved. This should allow for better keep-alive connection support. (See [#183](https://github.com/NREL/api-umbrella/pull/183))

### Everything Else

* **Fix bug causing 404s after publishing API backends:** If a default host was not set, publishing new API backends could make the admin inaccessible. (See [#192](https://github.com/NREL/api-umbrella/issues/192) and [#193](https://github.com/NREL/api-umbrella/issues/193))
* **Add concept of API key accounts with verified e-mail addresses:** APIs can now choose to restrict access to only API keys that have verified e-mail addresses. (See [api.data.gov#225](https://github.com/18F/api.data.gov/issues/225))
* **Fix initial admin accounts missing API token:** The initial superuser accounts created via the config file did not have a token for making admin API requests. (See [#95](https://github.com/NREL/api-umbrella/issues/95) and [#135](https://github.com/NREL/api-umbrella/issues/135))
* **Support wildcard frontend/backend hostnames:** API Backends can be configured with wildcard hostnames. (See [api.data.gov#240](https://github.com/18F/api.data.gov/issues/240))
* **Allow admins to view full API keys:** Superuser admin accounts can now view full API keys in the admin tool. (See [api.data.gov#276](https://github.com/18F/api.data.gov/issues/276))
* **Log why API Umbrella rejects requests in the analytics:** In the analytics screens, now you can see why API Umbrella rejected a request (for example, over rate limit, invalid API key, etc). (See [api.data.gov#226](https://github.com/18F/api.data.gov/issues/226))
* **Add missing delete actions to admin items:** Add the ability to delete admins, admin groups, api scopes, and website backends. (See [#134](https://github.com/NREL/api-umbrella/issues/134) and [#152](https://github.com/NREL/api-umbrella/issues/152))
* **Fix bug when invalid YAML entered into backend config:** If invalid YAML was entered into the API backend config, it could cause the API to go down. (See [#153](https://github.com/NREL/api-umbrella/issues/153))
* **Add CSV download for all admin accounts:** The entire list of admin accounts can be downloaded in a CSV. (See [api.data.gov#182](https://github.com/18F/api.data.gov/issues/182))
* **Per domain rate limits:** If API Umbrella is serving multiple domains, it now defaults to keeping rate limits for each domain separate. (See [api-umbrella-gatekeeper#19](https://github.com/NREL/api-umbrella-gatekeeper/pull/19))
* **Allow for longer hostnames:** Longer hostnames can now be used with API frontends. (See [#168](https://github.com/NREL/api-umbrella/issues/168))
* **Fix API Drilldown not respecting time zone:** In the analytics system, the API Drilldown chart wasn't using the user's timezone like the other analytics charts. (See [api.data.gov#217](https://github.com/18F/api.data.gov/issues/217))
* **Add optional LDAP authentication for admin:** The admin can now be configured to use LDAP. (See [#131](https://github.com/NREL/api-umbrella/issues/131))
* **Allow for system-wide IP or user agent blocks:** IPs or user agents can now be configured to be blocked at the server level. (See [api.data.gov#220](https://github.com/18F/api.data.gov/issues/220))
* **Allow for system-wide redirects:** HTTP redirects can now be configured at the server level. (See [api.data.gov#239](https://github.com/18F/api.data.gov/issues/239))
* **Log metadata about registration origins:** If the signup form is being used across different domains, the origin of the signup is now logged. (See [api.data.gov#218](https://github.com/18F/api.data.gov/issues/218))
* **Fix handling of unexpected `format` param:** If the `format` was of an unexpected type, it could cause issues when returning an error response. (See [api.data.gov#223](https://github.com/18F/api.data.gov/issues/223))
* **Fix handling of unexpected `Authorization` header:** If the `Authorization` header was of an unexpected type, it could cause the request to fail. (See [api.data.gov#266](https://github.com/18F/api.data.gov/issues/266))
* **Fix null selector options in analytics query builder:** In the analytics query builder, the "is null" or "is not null" options did not work properly. (See [api.data.gov#230](https://github.com/18F/api.data.gov/issues/230))
* **Analytics views now default to exclude over rate limit requests:** In the analytics screens, over rate limit requests are no longer displayed by default (but can still be viewed if needed). (See [api.data.gov#241](https://github.com/18F/api.data.gov/issues/241))
* **Fix admin account creation in Firefox:** Creating new admin accounts was not functioning in Firefox. (See [api.data.gov#271](https://github.com/18F/api.data.gov/issues/271))
* **Allow for response caching when `Authorization` header is passed:** If the `Authorization` header is part of the API backend configuration, caching of these responses is now allowed. (See [api.data.gov#281](https://github.com/18F/api.data.gov/issues/281))
* **Allow for easier customization of contact URLs:** Custom contact URLs are now easier to set for individual API backends (See [api.data.gov#285](https://github.com/18F/api.data.gov/issues/285))

## 0.8.0 (2015-04-26)

This update fixes a couple of security issues and a few important bugs. It's highly recommended anyone running earlier versions upgrade to v0.8.0.

[Download 0.8.0 Packages](http://nrel.github.io/api-umbrella/download/)

### Upgrade Instructions

If you're upgrading a previous API Umbrella version, you must first stop API Umbrella manually (`sudo /etc/init.d/api-umbrella stop`) before installing the new package. 

### Hightlights

* **Fix cross-site-scripting vulnerability:** In the admin, there was a possibility of a cross-site-scripting vulnerability. (See [api.data.gov#214](https://github.com/18F/api.data.gov/issues/214))
* **Make it easier to route to new website pages:** Any non-API request will be routed to the website backend, making it easier to manage your public website content. In addition, different website content can now be served up for different hostnames. (See [api.data.gov#146](https://github.com/18F/api.data.gov/issues/146) and [#69](https://github.com/NREL/api-umbrella/issues/69))
* **New analytics querying interface:** The new interface for querying the analytics allows you to filter your analytics using drop down menus and form fields. This should be much easier to use than the raw Lucene queries we previously relied on. (See [#15](https://github.com/NREL/api-umbrella/issues/15) and [api.data.gov#168](https://github.com/18F/api.data.gov/issues/168))
* **Add ability to set API response headers:** This feature can be used to set headers on the API responses, which can be used to force CORS headers with API Umbrella. (See [#81](https://github.com/NREL/api-umbrella/issues/81) and [api.data.gov#188](https://github.com/18F/api.data.gov/issues/188))
* **Add feature to specify HTTPS requirements:** This feature can be used force HTTPS usage to access your APIs and can also be used to help transition new users to HTTPS-only. (See [api.data.gov#34](https://github.com/18F/api.data.gov/issues/34))
* **Allow for better customization of the API key signup confirmation e-mail:** The contents for the API key signup e-mail can now be better tailored for different sites. (See [api.data.gov#133](https://github.com/18F/api.data.gov/issues/133))
* **Fix file descriptor leak:** This could lead to an outage by exhausting your systems maximum number of file descriptors for setups with lots of API backends using domains with short-lived TTLs. (See [api.data.gov#188](https://github.com/18F/api.data.gov/issues/188))

### Everything Else

* **Fix possibility of very brief 503 errors:** For setups with lots of API backends using domains with short-lived TTLs, there was a possibility of rare 503 errors when DNS changes were being reloaded. (See [api.data.gov#207](https://github.com/18F/api.data.gov/issues/207))
* **Fix server log rotation issues:** There were a few issues present with a default installation that prevented log files from rotating properly, and may have wiped previous log files each night. This should now be resolved. (See [api.data.gov#189](https://github.com/18F/api.data.gov/issues/189))
* **Fix couple of edge-cases where custom rate limits weren't applied:** There were a couple of edge-cases in how API backends and users were configured that could lead to rate limits being ignored. (See [#127](https://github.com/NREL/api-umbrella/issues/127), [api.data.gov#201](https://github.com/18F/api.data.gov/issues/201), [api.data.gov#202](https://github.com/18F/api.data.gov/issues/202))
* **Fix situations where analytics may have not been logged for specific queries:** If a URL contained UTF-8 character or if a query parameter contained a date or time, there were certain situations where that request would fail to be logged in the analytics database. (See [api.data.gov#198](https://github.com/18F/api.data.gov/issues/198) and [api.data.gov#213](https://github.com/18F/api.data.gov/issues/213))
* **Fix proxy transforming backslashes into forward slashes in the URL:** If a URL contained a backslash character, it may have been transformed into a forward slash when the API backend received the request. (See [api.data.gov#199](https://github.com/18F/api.data.gov/issues/199))
* **Gracefully handle MongoDB replicaset changes:** API Umbrella should continue to serve requests with no downtime if the MongoDB primary server changes. (See [api.data.gov#200](https://github.com/18F/api.data.gov/issues/200))
* **Add registration source information to admin user list:** The user registration source is now shown in the user listing and can also be searched by the free-from search field. (See [api.data.gov#190](https://github.com/18F/api.data.gov/issues/190))
* **Fix broken pagination on the admin list of API backends:** The list of API backends didn't properly handle pagination when more than 50 backends were present. (See [api.data.gov#209](https://github.com/18F/api.data.gov/issues/209))
* **Fixes to URL encoding for advanced request rewriting:** If you were doing complex URL rewriting with "Route Pattern" rewrites under the Advanced Request Rewriting section, this fixes a variety of URL encoding issues.
* **Reduce duplicative nginx reloads for DNS changes:** If your system has several API backends with domains that have short-lived TTLs, there were a couple race conditions that could lead to nginx reloading twice on DNS changes. This is now fixed so the unnecessary, duplicate reload commands are gone. (See [api.data.gov#191](https://github.com/18F/api.data.gov/issues/191))
* **Fix incorrectly logging HTTPS requests as HTTP:** API Umbrella v0.7 introduced a bug the led to HTTPS requests being logged as HTTP requests in the analytics database. (See [api.data.gov#208](https://github.com/18F/api.data.gov/issues/208))
* **Fix analytics charts during daylight saving time:** During daylight saving time, the daily analytics charts in the admin may have contained an extra duplicate day with 0 results. (See [api.data.gov#147](https://github.com/18F/api.data.gov/issues/147))
* **Prevent all URL prefixes from being removed from API backends:** In the admin, it was possible to remove all URL prefixes from an API backend's configuration, leaving it in an invalid state (See [api.data.gov#215](https://github.com/18F/api.data.gov/issues/215))
* **Improve compatibility of install on systems with other Rubies present:** If you're installing API Umbrella on a system that already had something like rbenv/rvm/chruby installed, this should should fix some compatibility issues.
* **Build process improvements:** Various improvements to our build process for packaging new binary releases.
* **Upgrade bundled dependencies:**
  * Bundler 1.7.12 -> 1.7.14
  * ElasticSearch 1.4.2 -> 1.5.1
  * MongoDB 2.6.7 -> 2.6.9
  * nginx 1.7.9 -> 1.7.10
  * ngx_headers_more 0.25 -> 0.26
  * ngx_txid a41a705 -> f1c197c
  * Node.js 0.10.36 -> 0.10.38
  * OpenSSL 1.0.1l -> 1.0.1m
  * Ruby 2.1.5 -> 2.1.6
  * RubyGems 2.4.5 -> 2.4.6
  * Varnish 4.0.2 -> 4.0.3

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
