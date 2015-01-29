# API Umbrella Gatekeeper (LUA)

API Umbrella Gatekeeper is the custom reverse proxy that's used in [API Umbrella](http://github.com/NREL/api-umbrella). 
*This version is for development only, and is written in Lua [More informations](https://github.com/NREL/api-umbrella/issues/56)*

Issues for this project are [maintained here](https://github.com/NREL/api-umbrella/issues).  

## Usage

See [Running API Umbrella](https://github.com/NREL/api-umbrella#running-api-umbrella) for setup instructions.

## Features
####All the following informations are subject to quick change, while the LUA branch is still in active development.

### API Key Validation

Once a request hits API Umbrella Gatekeeper, it validates that a valid API key has been passed with the request. If a valid API key is present, the request is allowed to hit the API backend (assuming the user has not exceeded their rate limits). If the API key is missing or invalid, then Gatekeeper immediately responds to the request and the request is not permitted to access the API backend.

API keys can be passed in three differnet, configurable ways:

- HTTP header
- GET parameter
- HTTP basic username

Currently, only simple API keys are supported, but it would be possible to extend API Umbrella Gatekeeper to support OAuth2 or other authentication mechanisms.

API keys are stored in MongoDB.

### Rate Limiting / Throttling

In addition to validating API keys, API Umbrella Gatekeeper also performs rate lmiting to ensure users don't overload your API backends. Rate limiting can be performed based on the users API key, IP address, or both. Rate limits can be configured in a number of ways: 

- Rate limit by API key, IP address, or both.
- Rate limit by any arbitrary rolling time window (per 1 second, per 15 minutes, per hour, per day, etc).
- Rate limits can be configured on a per API or per user basis.
- Rate limits can be  distributed and shared across hosting environemnts. This allowing for rate limits to still be efficiently applied if API Umbrella is distributed locally or geographically. 

Rate limiting uses both Redis and MongoDB.

### Logging & Analytics

Details on each incoming API request is asyncronously logged in a database to allow for near real time analytics of all your API usage. Various details are captured for each request:

- Basic details like request URL.
- Additional header information like, 
- Geographic information on where the request originated from.
- Response codes from the API backend, so you can look for requests that resulted in errors.
- Performance metrics: How long each request took to respond is captured, so you can see how your API performs and look for problem areas.
- Size metrics: Keep track of how many bytes are trasnferred for the request and the response.

The [API Umbrella Web](http://github.com/NREL/api-umbrella-web) application provides an administrative interface for browsing and querying the analtyics gathered.

Logs and analytics are gathered in ElasticSearch.

### API Facade / Request Rewriting

API Umbrella Gatekeeper can optionally modify the incoming request in a variety of ways. This allows your pulblic facing API to differ

- URL rewriting: The incoming URL can be transformed before hitting the backend. This can be as simple as presenting the API under a different URL prefix, or as complex as providing a completely different URL structure.
- Manipulate HTTP headers: Add or remove HTTP headers from the request before it hits the API backend.

The [API Umbrella Web](http://github.com/NREL/api-umbrella-web) application provides an administrative interface configuring the API backends and performing common types of rewriting.

## License

API Umbrella is open sourced under the [MIT license](https://github.com/NREL/api-umbrella-gatekeeper/blob/master/LICENSE.txt).

## Acknowledgements

Geographic data comes from GeoLite data created by [MaxMind](http://www.maxmind.com).

[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/dcca3eb5f7decb43edcd988b8b923393 "githalytics.com")](http://githalytics.com/NREL/api-umbrella-gatekeeper)
