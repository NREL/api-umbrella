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

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/9caf7fc8bb54ccd9e1670affa6b82618 "githalytics.com")](http://githalytics.com/NREL/api-umbrella)