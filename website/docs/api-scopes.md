API Scopes are combined with the Admin Groups to create a granular permission system within the API Umbrella admin. This might be useful if you have multiple organizations or departments that should only have access to certain parts of the API Umbrella admin.

An API Scope defines a hostname and a path prefix. This determines the API backends and analytics that an admin is allowed to view. For example, an admin may be authorized to interact with *example.com/foo/** apis, but not *example.com/bar/** apis. 

Next, you setup a (permissions) group, which defines the specific permissions admins can perform within API scopes. For example, you may want some admins to only be able to view analytics, while others should be able to also setup API backends.

As a quick example, say you set up an API Scope with a host of *example.com* and a path prefix of */foo*. You then create a group that uses that scope and grants the *Analytics and API Backend Configuration - View & Manage* permissions. Then, you assign that group to a specific admin account. 

Now, any admin that belongs to that group can log in and view analytics, but only for requests beginning with *example.com/foo/**. They would not be able to view analytics for *example.com/bar/**. Similarly, because they were granted the API Backend permission, that user could edit or create new API backends, but only as long as the API backend they're interacting with starts with *example.com/foo/** for it's public URL. However, while this specific admin group could add and edit API backends, they couldn't actually publish the backend changes and make them live, since they were not granted the *API Backend Configuration - Publish* permission.
