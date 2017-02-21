# Database Configuration

## Bind Address

By default, API Umbrella's bundled databases only accept connections from the same server. If you're running multiple servers, you'll need to adjust the [bind address settings](multi-server.html#bind-address).

## MongoDB Authentication

1. Create a user account for API Umbrella:

   ```
   $ /opt/api-umbrella/embedded/bin/mongo --port 14001
   > use api_umbrella
   > db.createUser({
       user: "api_umbrella",
       pwd: "super_secret_password_here",
       roles: [
         { role: "readWrite", db: "api_umbrella" },
         { role: "dbAdmin", db: "api_umbrella" },
       ]
     })
   > exit
   ```

1. Enable authorization and add the login details to the `mongodb.url` setting (using the [Connection String URI Format](https://docs.mongodb.org/manual/reference/connection-string/)) inside the `/etc/api-umbrella/api-umbrella.yml` config file:

   ```yaml
   mongodb:
     url: "mongodb://api_umbrella:super_secret_password_here@127.0.0.1:14001/api_umbrella"
     embedded_server_config:
       security:
         authorization: enabled
   ```

1. Restart API Umbrella: `sudo /etc/init.d/api-umbrella restart`

## External Database Usage

API Umbrella bundles the recommended database versions inside its package. Using other database versions is not supported, but should work. A few known notes about compatibility:

- Elasticsearch 1
  - API Umbrella can be used with an Elasticsearch 1 instance by setting the following config option in `/etc/api-umbrella/api-umbrella.yml`:

    ```yaml
    elasticsearch:
       api_version: 1
    ```
- Elasticsearch 5
  - API Umbrella is not yet compatible with Elasticsearch 5.
