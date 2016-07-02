# Database Configuration

## MongoDB Authentication

1. API Umbrella is not yet compatible with the new [SCRAM-SHA-1](https://docs.mongodb.org/manual/core/security-scram-sha-1/) authentication mechanism (the default in MongoDB 3.0 and higher). In order to create compatible user accounts for API Umbrella, you must first force MongoDB to create accounts with the old [MONGODB-CR](https://docs.mongodb.org/manual/core/security-mongodb-cr/) mechanism:

   ```
   use admin
   db.system.version.update({ "_id" : "authSchema" }, { "currentVersion": 3 })
   ```

   See [SERVER-17459](https://jira.mongodb.org/browse/SERVER-17459?focusedCommentId=842843&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-842843) for further discussion.

2. Create a user account for API Umbrella:

   ```
   use api_umbrella
   db.createUser({
     user: "api_umbrella",
     pwd: "super_secret_password_here",
     roles: [
       { role: "readWrite", db: "api_umbrella" },
       { role: "dbAdmin", db: "api_umbrella" },
     ]
   })
   ```

3. Add the login details and `authMechanism` option to the `mongodb.url` setting (using the [Connection String URI Format](https://docs.mongodb.org/manual/reference/connection-string/)) inside the `/etc/api-umbrella/api-umbrella.yml` config file:

   ```yaml
   mongodb:
     url: "mongodb://api_umbrella:super_secret_password_here@your-mongodb-host.example.com:27017/api_umbrella?authMechanism=MONGODB-CR"
   ```

## External Database Usage

API Umbrella bundles the recommended database versions inside its package. Using other database versions is not supported, but should work. A few known notes about compatibility:

- MongoDB 3.2
  - API Umbrella is not yet compatible with MongoDB 3.2's new default WiredTiger storage engine. However, things should work if you use the previous storage engined:

    ```yaml
    storage:
       engine: mmapv1
    ```

- Elasticsearch 2
  - API Umbrella can be used with an Elasticsearch 2 instance by setting the following config option in `/etc/api-umbrella/api-umbrella.yml`:

    ```yaml
    elasticsearch:
       api_version: 2
    ```
