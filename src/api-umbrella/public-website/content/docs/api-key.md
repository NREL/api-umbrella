---
title: API Key Usage
hidden_child: true

---

HELLO {{ $.Site.Params.githubRepoUrl }}
After [signing up](/signup), you'll be given your own, unique API key. This 40 character string is your API key. The key:

- Uniquely identifies you.
- Gives you access to Data.gov's Web services.
- Should be kept private and should not be shared.

To use your key, simply pass the key as a URL query parameter when making Web service requests. For example:

`GET http://api.data.gov/nrel/alt-fuel-stations/v1.json?api_key=YOUR_KEY_HERE`

Regardless of the HTTP method being called, the API key should always be passed as a GET parameter in the URL query. So even if you will be POSTing or PUTing to an specific service, the *api_key* query parameter should always be supplied in the URL query parameters.

## Alternative Method

Depending on your usage, it can sometimes be easier to pass the API key along as HTTP Basic authentication. If you want to use this method, pass your API key in as the username, while leaving the password blank. For example:

`GET http://YOUR_KEY_HERE@api.data.gov/nrel/alt-fuel-stations/v1.json`
