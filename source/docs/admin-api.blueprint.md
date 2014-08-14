# API Umbrella Admin API

The admin API is accessible via `/api-umbrella/v1`. In order to access this API, you must pass:

- Your API key via one of the [supported methods](http://nrel.github.io/api-umbrella/docs/api-keys/).
- **AND** an admin token via the `X-Admin-Auth-Token` header.

To find the admin auth token for your admin account, login the web admin tool, and choose "My Account" under the top right gear menu. On that page, you should see your "Admin API Token" listed. Use this in conjunction with your normal API key to make requests to the admin APIs:

```http
X-Api-Key: YOUR_API_KEY_HERE
X-Admin-Auth-Token: YOUR_ADMIN_TOKEN_HERE
```

# Group Users / API Keys

## User Collection [/api-umbrella/v1/users]

### Get All Users [GET]
TODO

### Create New User [POST]

+ Request

    + Headers

            Content-Type: application/json
            X-Api-Key: YOUR_API_KEY_HERE
            X-Admin-Auth-Token: YOUR_ADMIN_TOKEN_HERE

    + Body

            {
              "user":{
                "email":"john.doe@example.com",
                "first_name":"John",
                "last_name":"Doe",
                "use_description":"",
                "terms_and_conditions":true,
                "send_welcome_email":false,
                "throttle_by_ip":false,
                "roles":["write_access"],
                "enabled":true,
                "settings":{
                  "rate_limit_mode":null,
                  "rate_limits":[]
                }
              }
            }

+ Response 201

    + Headers

            Content-Type: application/json; charset=utf-8

    + Body

            {
              "user":{
                "id":"4339b882-1f7a-4f19-aa84-273c876a5f3d",
                "api_key":"2gcg6Gvq4a2evmdp69AsS1I6v7x1KJYaMJQIhQ3D",
                "api_key_hides_at":"2014-03-27T05:28:25Z",
                "api_key_preview":"2gcg6G...",
                "first_name":"John",
                "last_name":"Doe",
                "email":"john.doe@example.com",
                "website":null,
                "use_description":"",
                "registration_source":"web_admin",
                "throttle_by_ip":false,
                "roles":["write_access"],
                "enabled":true,
                "created_at":"2014-03-27T05:18:25Z",
                "updated_at":"2014-03-27T05:18:25Z",
                "settings":{
                  "id":"aa22932d-aecb-47a3-9ef3-806bf89e7a21",
                  "rate_limit_mode":null,
                  "rate_limits":[
                  ]
                },
                "creator":{
                  "username":"admin@example.com"
                },
                "updater":{
                  "username":"admin@example.com"
                }
              }
            }

+ Response 422

    + Headers

            Content-Type: application/json; charset=utf-8

    + Body

            {
              "errors":[
                {
                  "code":"INVALID_INPUT",
                  "message":"Provide a valid email address.",
                  "field":"email"
                }
              ]
            }

## User [/api-umbrella/v1/users/{id}]

+ Parameters

    + id (required, string, `bc7e8a90-b569-11e3-a5e2-0800200c9a66`) ... The user account ID

### Get User [GET]

+ Response 200

    + Headers

            Content-Type: application/json; charset=utf-8

    + Body

            {
              "user":{
                "id":"4339b882-1f7a-4f19-aa84-273c876a5f3d",
                "api_key_preview":"2gcg6G...",
                "first_name":"John",
                "last_name":"Doe",
                "email":"john.doe@example.com",
                "website":null,
                "use_description":"",
                "registration_source":"web_admin",
                "throttle_by_ip":false,
                "roles":["write_access"],
                "enabled":true,
                "created_at":"2014-03-27T05:18:25Z",
                "updated_at":"2014-03-27T05:18:25Z",
                "settings":{
                  "id":"aa22932d-aecb-47a3-9ef3-806bf89e7a21",
                  "rate_limit_mode":null,
                  "rate_limits":[
                  ]
                },
                "creator":{
                  "username":"admin@example.com"
                },
                "updater":{
                  "username":"admin@example.com"
                }
              }
            }

### Update User [PUT]

+ Request

    + Headers

            Content-Type: application/json
            X-Api-Key: YOUR_API_KEY_HERE
            X-Admin-Auth-Token: YOUR_ADMIN_TOKEN_HERE

    + Body

            {
              "user": {
                "enabled": false
              }
            }

+ Response 200

    + Headers

            Content-Type: application/json; charset=utf-8

    + Body

            {
              "user":{
                "id":"422ed2fc-6e8d-456d-9253-4e0fe9735bdc",
                "api_key_preview":"upHYhK...",
                "first_name":"John",
                "last_name":"Doe",
                "email":"john.doe@example.com",
                "website":null,
                "use_description":"",
                "registration_source":"web_admin",
                "throttle_by_ip":false,
                "roles":["write_access"],
                "enabled":false,
                "created_at":"2014-03-27T05:23:41Z",
                "updated_at":"2014-03-27T05:39:44Z",
                "settings":{
                  "id":"055fde68-0586-4780-a904-ba07df020cf1",
                  "rate_limit_mode":null,
                  "rate_limits":[
                  ]
                },
                "creator":{
                  "username":"admin@example.com"
                },
                "updater":{
                  "username":"admin@example.com"
                }
              }
            }

+ Response 422

    + Headers

            Content-Type: application/json; charset=utf-8

    + Body

            {
              "errors":[
                {
                  "code":"INVALID_INPUT",
                  "message":"Provide a valid email address.",
                  "field":"email"
                }
              ]
            }

# Group API Backends

## API Backend Collection [/api-umbrella/v1/apis]

### Get All API Backends [GET]
TODO

### Create New API Backend [POST]

## API Backend [/api-umbrella/v1/apis/{id}]

+ Parameters

    + id (required, string, `e5708670-b568-11e3-a5e2-0800200c9a66`) ... The API backend ID

### Get API Backend [GET]

### Update API Backend [PUT]

# Group Admin Accounts

## Admin Collection [/api-umbrella/v1/admins]

### Get All Admins [GET]
TODO

### Create New Admin [POST]

## Admin [/api-umbrella/v1/admins/{id}]

+ Parameters

    + id (required, string, `c3890fe0-b569-11e3-a5e2-0800200c9a66`) ... The admin account ID

### Get Admin [GET]

### Update Admin [PUT]

