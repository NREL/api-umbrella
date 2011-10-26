# developer.nrel.gov Software Architecture

## The Big Picture

![Web server architecture](images/software_architecture.png)

## Design Goals

The architecture is designed to allow for any number of independent web service backend applications to co-exist under a single framework. Common functions, such as authentication against a single user database, rate limiting, and statistics can all be provided by the framework in a uniform way. This frees each individual web service backend application from implementing the same logic. This also allows for the individual web service backend applications to exist on different servers, be written in different programming languages, or vary in any other way.

## Project Separation

You'll notice in the diagram that things are separated into `developer_apps` and `developer_router`. These are our two separate projects for the developer.nrel.gov framework.

The `developer_router` project consists of our configuration for our two HAProxy routing servers, as well as our custom ProxyMachine server code. This project is only deployed once on each server. Aside from possibly adding services to the API Router's configuration, it's code should be rather static.

The `developer_apps` project consists of Public Site application, as well as any web service applications that want to join our codebase on our developer.nrel.gov servers. While this project is only deployed once on the production server, it can also be sandboxed on our development servers, allowing developers to effectively have completely separate development instances.

Additional web service applications can exist outside of these projects, with the API Router just needing to point to wherever those services are hosted. However, by placing web services within the `developer_apps` project, the services can then take advantage of our deployment and cloud-based hosting.

Wondering more about the reasons behind this project separation and architecture? See [why the two projects exist](#why_two_projects).

## A day in the life of an incoming request

But what does that spaghetti of a diagram mean? That's probably best explained by stepping through how a request is handled.

1. A request is sent from a client to http://developer.nrel.gov
2. The Public Router (the first HAProxy server) receives the request on port 80.
3. The Public Router decides how to handle the request.
   1. Any request starting with `/api` will routed to our Auth Proxy (a ProxyMachine server). [Follow this path!](#api_requests)
   2. All other requests (for example, `/`, `/signup`, `/docs`) will be sent to our "Public Site" Ruby on Rails application. [Follow this path!](#public_site_requests)

### Public Site requests {#public_site_requests}

All non API requests coming to developer.nrel.gov are simply handed off to our "Public Site" Ruby on Rails application. This application handles all of the public facing content that appears to users when they go to developer.nrel.gov in their browser. This includes:

* Our home page
* API key signup
* API documentation and navigation
* A separate, private administrative application for us to perform tasks.

### /api requests {#api_requests}

#### Auth Proxy - Authentication, rate limiting, and statistics

API requests fall deeper down the rabbit hole. After the initial Public Router identifies an /api request, the request gets passed onto our authentication ProxyMachine server. This authentication proxy acts as a gatekeeper, performing several tasks:

1. The GET parameter `api_key` is extracted from the request and validated against the user accounts and roles in the MongoDB database. [Why MongoDB for user accounts?](#why_mongodb_users)
2. Requests from the same API key are rate limited using a Redis database. [Why Redis for rate limiting?](#why_redis)
3. Statistics are gathered for the request and inserted into the MongoDB database. [Why MongoDB for statistics?](#why_mongodb_stats)

If authentication or rate limiting fail, the request ends and the Auth Proxy server sends back an appropriate HTTP error status code and error message in the body. The error message body is returned in the format matching the request format. For example, an error occurring on `/api/fuel_stations.xml` will return an XML error message, while `/api/fuel_stations.json` will return an JSON error message. If no format can be detected, XML error messages are the default.

If authentication succeeds and the user is below the imposed rate limits, Auth Proxy returns nothing, but instead passes the request onto our API Router server (the second HAProxy server).

By performing these common tasks (authentication, rate limiting, and statistics) at this higher level, we can guarantee that all API requests are handled in the same fashion, errors will be returned in the same way, and the each web service application doesn't need to be concerned with handling these details.

#### API Router

If the client request has met all of Auth Proxy's requirements, it ends up at our second HAProxy server, the API Router. This server's job is to route API requests to the appropriate backend web services application. The routing is based on the request URL, so HAProxy is configured to identify certain URLs and map those to a specific web services backend. Supposing the client request was for `/api/fuel_stations/nearest.json`, HAProxy could be configured to route any requests beginning with `/api/fuel_stations` to our Sustainable Fuels & Vehicles web services application backend. At the same time, HAProxy could also be configured to route any requests beginning with `/api/openpv` to a separate OpenPV web services application.

The client request can also be modified by the API Router at this stage (within HAProxy's configuration file). Modifications will typically involve changing the URL that the backend application sees. This allows for a different public URL structure than what the backend is configured to respond to. For example, a backend may be configured to respond to `/fuel_stations/nearest.json`, but the public URL is going to be `/api/fuel_stations/nearest.json`. HAProxy can be configured to strip the `/api` prefix before sending the request to the appropriate backend. Similarly, entire URLs could be changed, allowing a public URL like `/api/something.json` to be routed to the backend as `/web_services/transportation/trucks/something_else.json`.

If HAProxy is unable to find a matching URL and backend server, HAProxy will respond with an error code response.

#### Web service backends

After the HAProxy web services router determines the correct backend application to send the request to, the appropriate backend receives the client request. The backend server sees the request as a normal incoming request, handles the request, and sends the response back. The response makes its way back up through the chain of proxy servers, finally arriving back to the client.

## Notes

### Why all the reverse proxies? / Proxy request streaming

You might be wondering why all this logic in the multiple routers and reverse proxies isn't simply handled by a single PHP or Rails application. The main reason is that those type of applications like to buffer incoming requests. For performance reasons, it's important that the various proxy servers for API requests don't buffer incoming requests or outgoing responses. Instead, data should always be streamed in chunks as they are received.

Both HAProxy and ProxyMachine behave in this streaming fashion way by default. With our configuration, the HAProxy servers only read the beginning of a request's headers to determine its URL. The ProxyMachine server reads a bit more, reading a request's entire headers so it has access to various things (GET parameters supplying the `api_key`, IP address of the client, etc). However, beyond reading those limited headers, none of the proxy servers ever read the entire request or the request body.

If changes are introduced to the proxy server framework, it's important to understand this and not introduce any complexity that relies on reading a request's body or buffering the entire request.

To illustrate a bad scenario, imagine a web service that requires uploading a 100MB file and returns 200MB of raw data in response. If each proxy between the client and backend application server buffered the entire request and response, there would be significant overhead and delays with each proxy server encountered. As currently designed, the proxies may read some of the headers for incoming requests, but after that, the request body is streamed to the next server as the request is still being received. The final server's response will also be streamed back to the client, with each proxy in between passing along data as soon as it's received.

### Aren't the Public Router and API Router servers redundant? Couldn't all the routing be done directly in the Auth Proxy server?

Yes, all the routing could be done directly inside a single Auth Proxy ProxyMachine server. However, ProxyMachine only deals with raw HTTP headers and doesn't have a variety of useful features HAProxy has for routing requests. The main features we use are altering the incoming URL (for example, stripping the "/api" from the URL before sending to the web service backend), and round-robin routing (so we can load balance servers and route to one of the many servers available). Yes, all of this could theoretically be achieved directly in ProxyMachine, but we'd have to implement it. HAProxy already provides these features, and they're well tested. So we only implement the higher-level, custom logic in ProxyMachine and leave the rest of the routing to HAProxy.

### Scalability

One side effect of this architecture is its theoretical scalability. As depicted in the diagram, everything except the initial Public Router HAProxy server can exist in clusters. All of our routing is handled through HAProxy and we've configured HAProxy to treat each possible backend as a server farm. Right now, our server farms might only be one server, but more servers could be added to a farm, and then HAProxy can load balance requests through all available servers.

### Why two projects with `developer_apps` and `developer_router`? {#why_two_projects}

There are any number of ways to split these various components up. Each individual component could be split into separate projects, deployed and managed completely separately. Or everything could belong to one monolithic project.

**One monolithic project:** This is actually how things used to be organized. The one "advantage" this had is that all of the routing servers were also sandboxed on the development servers for each developer. However, because the routers are all servers with ports, it lead to unwieldy dynamic configuration scripts that were difficult to follow, since each deployment of our site had to find free server ports to run all the individual servers on. Each deployment then had its own Auth Proxy, API router, and individual services running on different, randomized ports. It was difficult to follow the flow of a request with this level of dynamic configuration. By only sandboxing the applications, and only having a single deployment of the routers, this significantly reduces the complexity, while still allowing sandboxes for the code that is mostly likely to change (the applications).

**Completely separate projects:** Each component of the router and each individual web service application could be managed and deployed separately. This modular approach is appealing in some ways, however the main problem is then synchronizing deployments. When I send a new service live, I typically want the documentation to go live at the same time as the service. With the Public Site and the web service applications belonging to the same project, this deployment synchronization is handled automatically.

### Why Redis for rate limiting? {#why_redis}

[Redis](http://code.google.com/p/redis/) is a blazingly fast key value store. To rate limit an API key, we simply add a value for each request's API key and the hour it was accessed. Redis supports atomically incrementing values, so we can easily increment this counter for each request that comes in from the same API key within the same hour. We can follow a similar pattern for each API key's requests in a single day, and use these counters to quickly see if an API key is over any hourly or daily rate limits.

Redis also easily integrates with the existing [Rack::Throttle](http://github.com/datagraph/rack-throttle) project. We can use this rack middleware inside our ProxyMachine server to simplify the rate limiting logic.

Redis persists data to disk, however the entire database must fit into memory. So while it isn't suitable for storing large amounts of data forever, it's well suited for this application, where old data can be removed after a day. 

While MongoDB also has some of these characteristics (atomically incrementing counters), and we could probably use it, it doesn't integrate by default with Rack::Throttle, and theoretically Redis's in-memory system is faster.

### Why MongoDB for statistics? {#why_mongodb_stats}

[MongoDB](http://www.mongodb.org/) is a database system that has a couple of features that make it well suited for logging statistics. Like Redis, it supports atomic increment operations on counters, making it easy to keep counters of the things we care about. It doesn't match Redis's speed as a pure key-value store, but it's still plenty fast and supports asynchronous update/insert calls. This actually makes it even better suited for logging, since we can send data to MongoDB to log, but we don't have to wait for it to actually write the data to the database or return a result. This keeps the overhead of gathering statistics to a bare minimum. Also, unlike Redis, the entire database doesn't have to be stored in memory, so it can easily handle long-term storage and archiving of statistics.

### Why MongoDB for user accounts? {#why_mongodb_users}

The main reason we're using MongoDB is that it's [well suited for statistics](#why_mongodb_stats). Rather than introduce another database system, we're also using MongoDB for API user accounts.
