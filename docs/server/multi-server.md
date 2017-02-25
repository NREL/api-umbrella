# Multi-Server Setup

A [basic install](#basic-install) will result in all of the API Umbrella services running on a single server. You may wish to scale your installation to multiple servers for redundancy or performance reasons.

## Services

The first thing to understand with a multi-server installation are the individual services that can be run on each server. By default, all required services are run, but you can explicitly configure which services get run if you wish to split things off to different servers (for example, separating your database servers from your proxy servers).

To define which services get run, define the `services` configuration inside your `/etc/api-umbrella/api-umbrella.yml` configuration file:

```yaml
services:
  - general_db
  - log_db
  - router
  - web
```

This configuration enables all the available services. To disable a service, remove its line from the configuration.

The services available are:

- `general_db`: The MongoDB database used for configuration, user information, and other miscellaneous data.
- `log_db`: The Elasticsearch database used for logging and analytics.
- `router`: The core reverse proxy and routing capabilities of API Umbrella.
- `web`: The web application providing API Umbrella's administration app and REST APIs.

## Suggested Server Setups

In general, you'll need at least 3 servers in a multi-server setup since the database servers need an odd number of members for failover and voting purposes (see [MongoDB Replica Set Strategies](https://docs.mongodb.org/manual/core/replica-set-architectures/#deploy-an-odd-number-of-members)). Here are some possible server setups:

- 3 servers with all services running on all servers:
  - 3 servers with `router`, `web`, `general_db`, and `log_db` services enabled.
- 5 servers with the databases running on separate servers:
  - 2 servers with `router` and `web` services enabled.
  - 3 servers with `general_db` and `log_db` services enabled.
- 4 servers with the databases running on separate servers, and a MongoDB arbiter running on one of the proxy servers for voting purposes:
  - 1 server with `router` and `web` services enabled.
  - 1 server with `router`, `web`, `general_db` services enabled (but with MongoDB configured to be an arbiter for voting purposes only).
  - 2 servers with `general_db` and `log_db` services enabled.

## Load Balancing

If you have multiple proxy or web servers running, you'll need to load balance between these multiple API Umbrella servers from an external load balancer. For a highly available setup, using something like an AWS ELB (or your hosting provider's equivalent) is probably the easiest approach. Alternatives involve setting up your own load balancer (nginx, HAProxy, etc).

## Database Configuration

### Bind Address

By default, the database processes bind to `127.0.0.1`, which means they will only accept connections from the same server. If you decide to run the database processes on separate servers, or you have multiple database servers, then you'll need to adjust the bind addresses to allow for communication between servers.

**Warning:** Elasticsearch offers no built-in security, and by default, passwords are not enabled on MongoDB. So it's important that you do not expose the servers to the public or unprotected networks.

Changing the bind addresses to `0.0.0.0` will allow for database communication between servers, but this setting is only appropriate if you have other firewall or network restrictions in place to prevent public access. Again, **be careful** not to expose your database servers to the internet.

For the Elasticsearch servers (any server with the `log_db` role):

```yaml
elasticsearch:
  embedded_server_config:
    network:
      host: 127.0.0.1
```

For the MongoDB servers (any server with the `general_db` role):

```yaml
mongodb:
  embedded_server_config:
    net:
      bindIp: 127.0.0.1
```

### Multiple Servers

If you have multiple database servers, you'll need to adjust the `/etc/api-umbrella/api-umbrella.yml` configuration on all the servers to define the addresses of each database servers.

For the Elasticsearch servers (any server with the `log_db` role), define the server IPs:

```yaml
elasticsearch:
  hosts:
    - http://10.0.0.1:14002
    - http://10.0.0.2:14002
    - http://10.0.0.3:14002
```

For the MongoDB servers (any server with the `general_db` role), define the server IPs and replica set name:

```yaml
mongodb:
  url: "mongodb://10.0.0.1:14001,10.0.0.2:14001,10.0.0.3:14001/api_umbrella"
  embedded_server_config:
    replication:
      replSetName: api-umbrella
```

Note that for MongoDB, you'll still need to follow the normal procedure to [deploy a replica set](https://docs.mongodb.com/manual/tutorial/deploy-replica-set/) (for example, running `rs.initiate()`). In order to connect to MongoDB on the API Umbrella servers you can use this command: `/opt/api-umbrella/embedded/bin/mongo --port 14001`
