# SMTP Configuration

In order for end-users to receive email notifications, API Umbrella needs to be configured with SMTP settings.

Inside the `/etc/api-umbrella/api-umbrella.yml` config file, add SMTP settings under the *web.mailer.smtp_settings* key. The configuration under this key gets passed directly to Rails's **Action Mailer smtp_settings** configuration.

As a quick example, your configuration might look something like:

```yaml
web:
  mailer:
    smtp_settings:
      address: smtp.whatever.com
      authentication: login
      user_name: example
      password: super_secure_pass
```

Refer to the [Action Mailer docs](http://api.rubyonrails.org/classes/ActionMailer/Base.html) `smtp_settings` section for all the available options.
