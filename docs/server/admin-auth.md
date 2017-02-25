# Admin Authentication

By default, API Umbrella's admin can be accessed with local admin accounts that can be created and managed without any further configuration.

The admin can also be configured to authenticate using external login providers (like Google, Facebook, or LDAP). These external login providers can be used in combination with local admin accounts, or local accounts can be disabled and external providers can be used exclusively.

## General Configuration

Custom authentication settings can be defined in `/etc/api-umbrella/api-umbrella.yml`. The following example shows some general configuration options:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - local
        - github
        - google
    initial_superusers:
      - your.email@example.com
    username_is_email: true
```

- `web.admin.auth_strategies.enabled`: An array of authentication providers that should be enabled for logging into the admin (defaults to `local`). Available providers:
  - `local`
  - `cas`
  - `facebook`
  - `github`
  - `gitlab`
  - `google`
  - `ldap`
  - `max.gov`
- `web.admin.initial_superusers`: An array of superuser admin accounts that should be created on startup (defaults to none). Subsequent admin accounts can be created via the admin interface, so this setting is only needed for initial setup.

  When the local login provider is enabled (default), you will be given an opportunity to create an admin account on your first visit to the admin tool, so this option should not be necessary (unless you want to prevent the first visitor from being allowed to create an admin account).

  This option is primarily useful when the local login provider is disabled and you're exclusively using external login providers.
- `web.admin.username_is_email`: Whether or not the admin's username is also their email address (defaults to `true`). Setting this to `false` allows for a separate non-email based username to be assigned to admin accounts.

## Local Login Provider

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - local
    password_length_min: 14
    password_length_max: 72
```

- `web.admin.password_length_min`: Minimum length of admin passwords (default `14`).
- `web.admin.password_length_max`: Maximum length of admin passwords (default `72`).

## External Login Providers

### CAS

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - cas
      cas:
        options:
          host: login.example.com
          login_url: /cas/login
          service_validate_url: /cas/serviceValidate
          logout_url: /cas/logout
          ssl: true
```

See [omniauth-cas](https://github.com/dlindahl/omniauth-cas) for further documentation.

### Facebook

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - facebook
      facebook:
        client_id: "YOUR_CLIENT_ID_HERE"
        client_secret: "YOUR_CLIENT_SECRET_HERE"
```

To register your API Umbrella server with Facebook and get the `client_id` and `client_secret`:

1. Login to your Facebook developer account and [add a new app](https://developers.facebook.com/apps/async/create/platform-setup/dialog/).
1. Click **Add Product** in the left menu, and on the **Product Setup** screen, choose **Facebook Login**.
1. The **Valid OAuth redirect URIs** should be: `https://yourdomain.com/admins/auth/facebook/callback` (use the domain where API Umbrella is deployed)
1. Click **App Review** in the left menu, and flip the switch to make the app public.
1. Click **Settings** in the left menu and find your **App ID** and **App Secret**.
1. Add your `client_id` and `client_secret` to `/etc/api-umbrella/api-umbrella.yml`.
1. Reload API Umbrella (`sudo /etc/init.d/api-umbrella reload`).

See [omniauth-facebook](https://github.com/mkdynamic/omniauth-facebook) for further documentation.

### GitHub

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - github
      github:
        client_id: "YOUR_CLIENT_ID_HERE"
        client_secret: "YOUR_CLIENT_SECRET_HERE"
```

To register your API Umbrella server with GitHub and get the `client_id` and `client_secret`:

1. Login to your GitHub account and create a [new application](https://github.com/settings/applications/new).
1. The **Homepage URL** should be: `https://yourdomain.com` (use the domain where API Umbrella is deployed)
1. The **Authorization callback URL** should be: `https://yourdomain.com/admins/auth/github/callback`
1. Add your `client_id` and `client_secret` to `/etc/api-umbrella/api-umbrella.yml`.
1. Reload API Umbrella (`sudo /etc/init.d/api-umbrella reload`).

See [omniauth-github](https://github.com/intridea/omniauth-github) for further documentation.


### GitLab

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - gitlab
      gitlab:
        client_id: "YOUR_CLIENT_ID_HERE"
        client_secret: "YOUR_CLIENT_SECRET_HERE"
```

To register your API Umbrella server with GitLab and get the `client_id` and `client_secret`:

1. Login to your GitLab account and create a [new application](https://gitlab.com/profile/applications).
1. The **Redirect URI** should be: `https://yourdomain.com/admins/auth/gitlab/callback` (use the domain where API Umbrella is deployed)
1. The **Scopes** should be: `read_user`
1. Add your `client_id` and `client_secret` to `/etc/api-umbrella/api-umbrella.yml`.
1. Reload API Umbrella (`sudo /etc/init.d/api-umbrella reload`).

See [omniauth-gitlab](https://github.com/linchus/omniauth-gitlab) for further documentation.

### Google

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - google
      google:
        client_id: "YOUR_CLIENT_ID_HERE"
        client_secret: "YOUR_CLIENT_SECRET_HERE"
```

To register your API Umbrella server with Google and get the `client_id` and `client_secret`:

1. Login to the [Google API Console](https://console.developers.google.com/iam-admin/projects).
1. Create a new project for your API Umbrella site.
1. Navigate to **API Manager** > **Library** and enable the **Contacts API** and **Google+ API** APIs.
1. Navigate to **API Manager** > **Credentials**.
1. Under the **OAuth consent screen** tab, enter a **Product name shown to users**.
1. Under the **Credentials** tab, click the **Create cedentials** button and pick **OAuth Client ID**.
1. The **Application Type** should be: **Web application**.
1. The **Authorized JavaScript origins** should be: `https://yourdomain.com` (use the domain where API Umbrella is deployed)
1. The **Authorized redirect URIs** should be: `https://example.com/admins/auth/google_oauth2/callback`
1. Add your `client_id` and `client_secret` to the **api-umbrella.yml**.
1. Reload API Umbrella (`sudo /etc/init.d/api-umbrella reload`).

See [omniauth-google-oauth2](https://github.com/zquestz/omniauth-google-oauth2) for further documentation.

### LDAP

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    username_is_email: false
    auth_strategies:
      enabled:
        - ldap
      ldap:
        options:
          title: Your Company
          host: ldap.example.com
          port: 389
          method: plain
          base: dc=example,dc=com
          uid: sAMAccountName
```

It may be useful to set `web.admin.username_is_email` to `false` if your LDAP account uses usernames (instead of email addresses) to authenticate.

See [omniauth-ldap](https://github.com/intridea/omniauth-ldap) for further documentation.

### MAX.gov

Example `/etc/api-umbrella/api-umbrella.yml` config:

```yaml
web:
  admin:
    auth_strategies:
      enabled:
        - max.gov
```

If your website is authorized to use MAX.gov, no further configuration is necessary.
