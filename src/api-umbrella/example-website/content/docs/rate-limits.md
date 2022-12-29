---
title: Web Service Rate Limits
generalDocs: true
---

Limits are placed on the number of API requests you may make using your API key. Rate limits may vary by service, but the defaults are:

- **Hourly Limit:** 1,000 requests per hour

For each API key, these limits are applied across all API requests. Exceeding these limits will lead to your API key being temporarily blocked from making further requests. The block will automatically be lifted by waiting an hour. If you need higher rate limits, [contact us](/contact/).

## DEMO_KEY Rate Limits

In documentation examples, the special `DEMO_KEY` api key is used. This API key can be used for initially exploring APIs prior to signing up, but it has much lower rate limits, so you're encouraged to [signup](/signup/) for your own API key if you plan to use the API (signup is quick and easy). The rate limits for the DEMO_KEY are:

- **Hourly Limit:** 30 requests per IP address per hour
- **Daily Limit:** 50 requests per IP address per day

## How Do I See My Current Usage?

Your can check your current rate limit and usage details by inspecting the `X-RateLimit-Limit` and `X-RateLimit-Remaining` HTTP headers that are returned on every API response. For example, if an API has the default hourly limit of 1,000 request, after making 2 requests, you will receive these HTTP headers in the response of the second request:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 998
```

## Understanding Rate Limit Time Periods

### Hourly Limit

The hourly counters for your API key reset on a rolling basis.

_Example:_ If you made 500 requests at 10:15AM and 500 requests at 10:25AM, your API key would become temporarily blocked. This temporary block of your API key would cease at 11:15AM, at which point you could make 500 requests. At 11:25AM, you could then make another 500 requests.

## Rate Limit Error Response

If your API key exceeds the rate limits, you will receive a response with an HTTP status code of 429 (Too Many Requests).

## Need Higher Limits?

If you're building an application that needs higher rate limits, please reach out to the owner responsible for the API you would like higher rate limits for.
