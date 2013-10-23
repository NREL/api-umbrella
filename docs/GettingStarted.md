# Getting Started

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
