# Role Restrictions

API Umbrella's "roles" feature can be used to restrict access to APIs so that only certain API keys may access certain APIs.

## Adding Roles to API Keys

To grant specific API keys a role:

1. In the Admin, under Users > API Users, find the API key you want to add roles to.
2. Under Permissions > Roles, enter roles to assign to this API key.
   - You can name roles however you'd like.
   - Existing roles will auto-complete, but new roles can be created by entering a new name.

## Enforcing Role Requirements With API Umbrella

If you'd like for API Umbrella to enforce role restrictions, then role requirements can be defined within the API Backend configuration:

1. In the Admin, under Configuration > API Backends, choose your API Backend to edit.
2. Under Global Request Settings > Required Roles, enter roles to require.
   - You can name roles however you'd like.
   - Existing roles will auto-complete, but new roles can be created by entering a new name.
   - If multiple roles are set, then the API key must have all of the roles.
3. Save changes to the API Backend and publish the configuration changes.

Once configured, then only API keys with the required roles will be able to access your API backend. If an API key lacks all of the required roles then API Umbrella will reject the request with a 403 Forbidden error and your API will never receive the request.

### Sub-URL Role Requirements

The API Backend's "Sub-URL Request Settings" can be used to define more granular role requirements. For example, this could be used to require roles on just a single API URL path, or to only require roles for POST/PUT write access.

## Enforcing Role Requirements Inside Your API

Instead of enforcing role requirements at the API Umbrella proxy layer, you can also utilize the role information in other ways within your API backend. If you have more complex authorization logic, then this may be easier to implement within your API's code.

On each request with a valid API key that's passed to your API backend, there's an `X-Api-Roles` HTTP header. This contains a comma-delimited list of all the roles assigned to the API key that's making the request. Your APIs can parse this HTTP header and use it to decide whether access should be permitted or denied.
