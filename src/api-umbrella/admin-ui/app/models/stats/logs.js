import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import { Promise } from 'rsvp';

@classic
class Logs extends EmberObject.extend(Evented) {
  static urlRoot = '/admin/stats/search.json';

  static fieldTooltips = {
    api_backend_id: t('The ID of the API backend that was matched by this request.\n*Example:* `ec4b7fb8-4e38-464a-81b1-bd044d08c848`'),
    api_backend_resolved_host: t('The IP address and port that was resolved and used for the API backend connection.\n*Example:* `10.226.13.172:443`'),
    api_backend_response_code_details: t('Diagnostic code that may provide details on why an API backend connection may have failed. See <a href="https://www.envoyproxy.io/docs/envoy/v1.26.2/configuration/http/http_conn_man/response_code_details.html" target="_blank">documentation on possilbe values</a>.\n*Example:* `no_healthy_upstream`'),
    api_backend_response_flags: t('Diagnostic flags that provide details on how the connection was established to the API backend server. See <a href="https://www.envoyproxy.io/docs/envoy/v1.26.2/configuration/observability/access_log/usage.html#config-access-log-format-response-flags" target="_blank">documentation on possilbe values</a>.\n*Example:* `UF,URX`'),
    api_key: t('The API key used to make the request.\n*Example:* `vfcHB9tOyFKc6YbbdDsE8plxtFHvp9zXIJWAtaep`'),
    gatekeeper_denied_code: t('If API Umbrella is responsible for blocking the request, this code value describes the reason for the block.\n*Example:* `api_key_missing`, `over_rate_limit`, etc.'),
    legacy_request_url: t('The original, complete request URL.\n*Example:* `http://example.com/geocode/v1.json?address=1617+Cole+Blvd+Golden+CO`\n*Note:* If you want to simply filter on the host or path portion of the URL, your queries will run better if you use the separate "Request: URL Path" or "Request: URL Host" fields.'),
    request_accept: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept" target="_blank">`Accept` header</a> sent on the request.\n*Example:* `application/json`'),
    request_accept_encoding: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Encoding" target="_blank">`Accept-Encoding` header</a> sent on the request.\n*Example:* `gzip`'),
    request_at: t('The time the request was made.'),
    request_connection: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Connection" target="_blank">`Connection` header</a> sent on the request.\n*Example:* `keep-alive`'),
    request_content_type: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type" target="_blank">`Content-Type` header</a> sent on the request.\n*Example:* `application/json`'),
    request_host: t('The host of the original request URL.\n*Example:* `example.com`'),
    request_id: t('Diagnostic ID of the request. This is passed both to the API Backend in the `X-Api-Umbrella-Request-Id` request header, and returned to the API client in the `X-Api-Umbrella-Request-Id` response header.\n*Example:* `aelqdj9lfoe7c2itheg0`'),
    request_ip: t('The IP address of the requestor.\n*Example:* `93.184.216.119`'),
    request_ip_city: t('The name of the city that the IP address geocoded to.\n*Example:* `Golden`'),
    request_ip_country: t('The 2 letter country code (<a href="http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2" target="_blank">ISO 3166-1</a>) that the IP address geocoded to.\n*Example:* `US`'),
    request_ip_region: t('The 2 letter state or region code (<a href="http://en.wikipedia.org/wiki/ISO_3166-2" target="_blank">ISO 3166-2</a>) that the IP address geocoded to.\n*Example:* `CO`'),
    request_method: t('The HTTP method of the request.\n*Example:* `GET`, `POST`, `PUT`, `DELETE`, etc.'),
    request_origin: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin" target="_blank">`Origin` header</a> sent on the request.\n*Example:* `https://example.com`'),
    request_path: t('The path of the original request URL.\n*Example:* `/geocode/v1.json`'),
    request_referer: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referer" target="_blank">`Referer` header</a> sent on the request.\n*Example:* `https://example.com/foo`'),
    request_scheme: t('The scheme of the original request URL.\n*Example:* `http` or `https`'),
    request_size: t('The size (in bytes) of the full HTTP request (including the request line, headers, and request body).\n*Example:* `283`'),
    request_url: t('The URL path and query string of the original request URL.'),
    request_url_query: t('The query string of the original request URL.\n*Example:* `address=1617+Cole+Blvd+Golden+CO&foo=bar`'),
    request_user_agent: t('The full <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent" target="_blank">user agent string</a> of the requestor.\n*Example:* `curl/7.33.0`'),
    request_user_agent_family: t('The overall family of the user agent.\n*Example:* `Chrome`'),
    request_user_agent_type: t('The type of user agent.\n*Example:* `Browser`'),
    response_age: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Age" target="_blank">`Age` header</a> sent on the response, indicating the age of a cached response.\n*Example:* `50`'),
    response_cache: t('The `X-Cache` header sent on the response, indicating whether the response was cached or not.\n*Example:* `HIT` or `MISS`'),
    response_cache_flags: t('Diagnostic flags returned in the `Via` HTTP response header that indicate how the caching layer handled the response. See the <a href="https://trafficserver.apache.org/tools/via.html" target="_blank">Via Decoder Ring</a> tool for deciphering these values or <a href="https://docs.trafficserver.apache.org/en/9.2.x/appendices/faq.en.html#how-do-i-interpret-the-via-header-code" target="_blank">more detailed documentation</a>.\n*Example:* `cMsSfW`'),
    response_content_encoding: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Encoding" target="_blank">`Content-Encoding` header</a> sent on the response.\n*Example:* `gzip`'),
    response_content_length: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Length" target="_blank">`Content-Length` header</a> sent on the response.\n*Example:* `3829`'),
    response_content_type: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type" target="_blank">`Content-Type` header</a> sent on the response.\n*Example:* `application/json; charset=utf-8`'),
    response_custom1: t('The value of the `X-Api-Umbrella-Analytics-Custom1` header sent on the response. This can be used by an API backend to send custom analytics information that will be collected and logged.\n*Example:* `hello-world`'),
    response_custom2: t('The value of the `X-Api-Umbrella-Analytics-Custom1` header sent on the response. This can be used by an API backend to send custom analytics information that will be collected and logged.\n*Example:* `hello-world`'),
    response_custom3: t('The value of the `X-Api-Umbrella-Analytics-Custom1` header sent on the response. This can be used by an API backend to send custom analytics information that will be collected and logged.\n*Example:* `hello-world`'),
    response_server: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server" target="_blank">`Server` header</a> sent on the API backend response. Note: the `Server` header may be changed or stripped from the API consumer\'s response, but this indicates the header that was received from the API backend before changes.\n*Example:* `Apache/2`'),
    response_size: t('The size (in bytes) of the full HTTP response (including headers and response body).\n*Example:* `4829`'),
    response_status: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Status" target="_blank">HTTP status code</a> returned for the response.\n*Example:* `200`, `403`, `429`, etc.'),
    response_time: t('The total amount of time taken to respond to the request (in milliseconds)'),
    response_transfer_encoding: t('The <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Transfer-Encoding" target="_blank">`Transfer-Encoding` header</a> sent on the response.\n*Example:* `gzip, chunked`'),
    user_email: t('The e-mail address associated with the API key used to make the request.\n*Example:* `john.doe@example.com`'),
    user_id: t('The user ID associated with the API key used to make the request.\n*Example:* `ad2d94b6-e0f8-4e26-b1a6-1bc6b12f3d76`'),
  }

  static find(params) {
    return new Promise((resolve, reject) => {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(Logs.create(data));
      }, function(data) {
        reject(data.responseText);
      });
    });
  }

  hits_over_time = null;
  stats = null;
  facets = null;
  logs = null;
}

export default Logs;
