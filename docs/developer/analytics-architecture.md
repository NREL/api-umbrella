# Analytics Architecture

## Overview

Analytics data is gathered on each request made to API Umbrella and logged to a database. The basic flow of how analytics data gets logged is:

```
[nginx] => [rsyslog] => [storage database]
```

To explain each step:

- nginx logs individual request data in JSON format to a local rsyslog server over a TCP socket (using [lua-resty-logger-socket](https://github.com/cloudflare/lua-resty-logger-socket)).
- rsyslog's role in the middle is for a couple of primary purposes:
  - It buffers the data locally so that if the analytics server is down or requests are coming in too quickly for the database to handle, the data can be queued.
  - It can transform the data and send it to multiple different endpoints.
- The storage database stores the raw analytics data for further querying or processing.

## Elasticsearch

### Ingest

Data is logged directly to Elasticsearch from rsyslog:

```
[nginx] ====> [rsyslog] ====> [Elasticsearch]
        JSON            JSON
```

- rsyslog buffers and sends data to Elasticseach using the Elasticsearch Bulk API.
- rsyslog's [omelasticsearch](http://www.rsyslog.com/doc/v8-stable/configuration/modules/omelasticsearch.html) output module is used.

### Querying

The analytic APIs in the web application directly query Elasticsearch:

```
[api-umbrella-web-app] => [Elasticsearch]
```
