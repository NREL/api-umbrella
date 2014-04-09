# Getting Started

### Login to the web admin

A web admin is available to perform basic tasks:

[http://localhost:8080/admin/](http://localhost:8080/admin/)

While in your local development environment, you can choose the dummy login option to login using any e-mail address (no password required).

### Add API Backends

Out of the box, API Umbrella doesn't know about any APIs. You must first configure the API backends that will be proxied to.

In this example, we'll proxy to Google's Geocoding API (but you'll more likely be proxying to your own web services).

**Step 1:** Login to the [web admin](http://localhost:8080/admin/) and navigate to the "API Backends" section under the "Configuration" menu.

**Step 2:** Add a new backend:

![Add API Backend Example](https://github.com/NREL/api-umbrella/raw/master/docs/images/add_api_backend_example.png)

**Step 3:** Navigate to the "Publish Changes" page under the "Configuration" menu and press the Publish button.

Google's API should now be available through the API Umbrella proxy.

### Signup for an API key

On your local environment, visit the signup form:

[http://localhost:8080/signup](http://localhost:8080/signup)

Signup to receive your own unique API key for your development environment.

### Make an API request

Assuming you added the Google Geocoding example as an API backend, you should now be able to make a request to Google's Geocoding API proxied through your local API Umbrella instance:

`http://localhost:8080/google/maps/api/geocode/json?address=Golden,+CO&sensor=false&api_key=**YOUR_KEY_HERE**`

You can see how API Umbrella layers its authentication on top of existing APIs by making a request using an invalid key:

[http://localhost:8080/google/maps/api/geocode/json?address=Golden,+CO&sensor=false&api_key=INVALID_KEY](http://localhost:8080/google/maps/api/geocode/json?address=Golden,+CO&sensor=false&api_key=INVALID_KEY)

### View Analytics

Login to the [web admin](http://localhost:8080/admin/). Navigate to the "Filter Logs" section under the "Analytics" menu. As you make API requests against your API Umbrella server, the requests should start to show up here (there may be a 30 second delay before the requests show up in the analytics).

![Analytics](https://github.com/NREL/api-umbrella/raw/master/docs/images/analytics.png)


### Write API documentation

Login to the [web admin](http://localhost:8080/admin/) and create documentation for individual web services and organize them into hierarchical collections. As documentation and collections are added, they will show up in the [documentation section](http://localhost:8080/doc) of the frontend.


### Roles
Roles are created by simply using a new role's name on either the API backend or API key side of things. It behaves like a tagging interface, so there's no explicit action needed to create a new role.

For global settings, when you define an API backend's configuration (eg, that api.data.gov/foo/ gets routed to wherever your server lives), you can assign a required role for accessing that entire API backend. This would mean that all requests to /foo/ would need to have an API key with this specific role assigned to it before it's able to access those APIs.

### Fine-Grained Access Control
You can also setup more granular rules under the "Sub-URL Request Settings." In there you can define required roles for more specific URLs within your API, allowing you to do things like define that /foo/bar/ and /foo/moo/ require separate roles. You can also assign these requires roles based on HTTP method access, so you can setup different required roles for POST vs GET vs PUT vs DELETE vs etc.

The most common thing we've done is to allow all API keys to have GET access by default, but then setup a sub-url request setting to restrict POST/PUT/DELETE access to specific roles. So, for example, everyone can access the GET API without any role, but only API keys with a "foo-write" role assigned to them can POST to the API.

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/9caf7fc8bb54ccd9e1670affa6b82618 "githalytics.com")](http://githalytics.com/NREL/api-umbrella)
