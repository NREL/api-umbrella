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

API Umbrella supports different analytics databases: 

## Elasticsearch

Suitable for small to medium amounts of historical analytics data. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*

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

## PostgreSQL

**TODO: The PostgreSQL adapter doesn't currently exist, but the idea is to leverage the same SQL framework built for Kylin.**

Suitable for small amounts of historical analytics data, or small to medium amounts of data with a columnar storage extension. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*

### Ingest

Data is logged directly to PostgreSQL from rsyslog:

```
[nginx] ====> [rsyslog] ===> [PostgreSQL]
        JSON            SQL
```

- rsyslog buffers and sends data to PostgreSQL as individual inserts.
- rsyslog's ompgsql output module is used.
- If rsyslog supports batched transactions in the future, we should switch to that: [rsyslog#895](https://github.com/rsyslog/rsyslog/issues/895)

### Querying

The analytic APIs in the web application directly query PostgreSQL:

```
[api-umbrella-web-app] ===> [PostgreSQL]
                       SQL
```

### PostgreSQL: Columnar Storage

For better analytics performance with larger volumes of analytics data, you can continue to use the PostgreSQL adapter, but with a compatible column-based variant:

- [cstore_fdw](https://github.com/citusdata/cstore_fdw)
- [Amazon Redshift](https://aws.amazon.com/redshift/)

When these are used, the SQL table design and process remains the same, only the underlying table storage is changed for better analytic query performance.

## Kylin

Suitable for large amounts of historical analytics data. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*

This is the most complicated setup, but it allows for vastly improved querying performance when dealing with large amounts of historical data. This is achieved by using [Kylin](http://kylin.apache.org) to pre-compute common aggregate totals. By pre-computing common aggregations, less hardware is needed than would otherwise be needed to quickly answer analytics queries over large amounts of data. Under this approach, analytics data may not be immediately available for querying, since additional processing is required.

### Ingest

During ingest, there are several concurrent processes that play a role:

```
[nginx] ====> [rsyslog] ====> [Kafka] ====> [Flume] ====> [HDFS - JSON (temp)]
        JSON            JSON          JSON          JSON
```

```
[HDFS - JSON (temp)] => [API Umbrella Live Processor] => [Hive - ORC]
```

```
[Hive - ORC] => [API Umbrella Kylin Refresher] => [Kylin]
```

- rsyslog buffers and sends JSON messages to Kafka using the [omkafka](http://www.rsyslog.com/doc/v8-stable/configuration/modules/omkafka.html) output module.
  - Kafka is used as an intermediate step as a reliable way to get messages in order to Flume, but primarily Kafka is being used because that's what Kylin's future [streaming feature](http://kylin.apache.org/blog/2016/02/03/streaming-cubing/) will require (so it seemed worth getting in place now).
- Flume takes messages off the Kafka queue and appends them to a gzipped JSON file stored inside Hadoop (HDFS).
  - The JSON files are flushed to HDFS every 15 seconds, and new files are created for each minute.
  - The per-minute JSON files are partitioned by the request timestamp and not the timestamp of when Flume is processing the message. This means Flume could be writing to a file from previous minutes if it's catching up with a backlog of data.
  - Kafka's stronger in-order handling of messages should ensure that the per-minute JSON files are written in order, and skipping between minutes should not be likely (although possible if an nginx server's clock is severely skewed or an nginx server goes offline, but still has queued up messages that could be sent if it rejoins later).
  - Flume plays a very similar role to rsyslog, but we use it because it has the best integration with the Hadoop ecosystem and writing to HDFS (I ran into multiple issues with rsyslog's native omhdfs and omhttpfs modules).
- The API Umbrella Live Processor task determines when a per-minute JSON file hasn't been touched in more than 1 minute, and then copies the data to the ORC file for permanent storage and querying in the Hive table.
  - The live data should usually make it's way to the permanent ORC storage within 2-3 minutes.
  - The ORC data is partitioned by day.
  - The data is converted from JSON to ORC using a Hive SQL command. Each minute of data is appended as a new ORC file within the overall ORC daily partition (which Hive simply treats as a single daily partition within the overall logs table).
  - Since the data is only appended, the same minute cannot be processed twice, which is why we give a minute buffer after the JSON file has ceased writing activity to convert it to ORC.
  - The ORC file format gives much better compression and querying performance than storing everything in JSON.
  - If a new ORC file is created for a new day, the partition will be added to the Hive table.
  - At the end of each day, overwrite the daily ORC file with a new, compacted file from the original JSON data. Writing the full day at once provides better querying performance than the many per-minute ORC files. By basing this daily file on the original JSON data, it also alleviates any rare edge-cases where the per-minute appender missed data.
  - Automatically remove old JSON minute data once it's no longer needed.
- The API Umbrella Kylin Refresher task is responsible for triggering Kylin builds to updated the pre-aggregated data.
  - At the end of each day, after writing the compacted ORC file for the full day, we then trigger a Kylin build for the most recent day's data.

This setup is unfortunately complicated with several moving pieces. However, there are several things that could potentially simplify this setup quite a bit in the future:

- [Kylin Streaming](http://kylin.apache.org/blog/2016/02/03/streaming-cubing/): This would eliminate our need to constantly refresh Kylin throughout the day, and reduce the amount of time it would take live data to become available in Kylin's pre-aggregated results. This feature available as a prototype in Kylin 1.5, but we're still on 1.2, and we'll be waiting for this to stabilize and for more documentation to come out. But basically, this should just act as another consumer of the Kafka queue, and then it would handle all the details of getting the data into Kylin.
- [Flume Hive Sink](https://flume.apache.org/FlumeUserGuide.html#hive-sink): Even with Kylin streaming support, we will likely still need our own way to get the live data into the ORC-backed Hive table. Flume's Hive Sink offers a way to directly push data from Flume into a ORC table. Currently marked as a preview feature, I ran into memory growth and instability issues in my attempts to use it, but if this proves stable in the future, it could be a much easier path to populating the ORC tables directly and get rid of the need for temporary JSON (along with the edge conditions those bring).
- [Kylin Hour Partitioning](https://issues.apache.org/jira/browse/KYLIN-1427): A possible shorter-term improvement while waiting for Kylin streaming is the ability to refresh Kylin by hour partitions. This would be more efficient than our full day refreshes currently used. This is currently implemented in v1.5.0, but we first need to upgrade to 1.5 (we're holding back at 1.2 due to some other issues), and then [KYLIN-1513](https://issues.apache.org/jira/browse/KYLIN-1513) would be good to get fixed before.

### Querying

The analytic APIs in the web application query Kylin or [PrestoDB](https://prestodb.io) using SQL statements:

```
                            /==> [Kylin] ====> [HBase Aggregates]
                           /
[api-umbrella-web-app] ===>
                       SQL \
                            \==> [PrestoDB] => [Hive ORC Tables]
```

- Queries are attempted against Kylin first, since Kylin will provide the fastest answers from it's pre-computed aggregates.
  - Kylin will be unable to answer the query if the query involves dimensions that have not been pre-computed.
  - We've attempted to design the Kylin cubes with the dimensions that are involved in the most common queries. These are currently:
    - `timestamp_tz_year`
    - `timestamp_tz_month`
    - `timestamp_tz_week`
    - `timestamp_tz_date`
    - `timestamp_tz_hour`
    - `request_url_host`
    - `request_url_path_level1`
    - `request_url_path_level2`
    - `request_url_path_level3`
    - `request_url_path_level4`
    - `request_url_path_level5`
    - `request_url_path_level6`
    - `user_id`
    - `request_ip`
    - `response_status`
    - `denied_reason`
    - `request_method`
    - `request_ip_country`
    - `request_ip_region`
    - `request_ip_city`
  - We don't add all the columns/dimensions to the Kylin cubes, since each additional dimension exponentially increases the amount of data Kylin has to pre-compute (which can significantly increase processing time and storage).
  - Data must be processed into Kylin for it to be part of Kylin's results, so the results will typically lag 30-60 minutes behind live data.
- If Kylin fails for any reason (the query involves a column we haven't precomputed or Kylin is down), then we perform the same query against PrestoDB. This queries the underlying ORC tables stored in Hive (which is the same raw data Kylin bases its data cubes on).
  - PrestoDB is used to provide an ANSI SQL layer on top of Hive. This should provide better compatibility with the SQL queries we're sending to Kylin, since both Kylin and PrestoDB aim for ANSI SQL compatibility (unlike Hive, which uses a different SQL-like HiveQL).
  - PrestoDB also offers better performance (significant in some cases) for our SQL queries rather than querying Hive directly. PrestoDB has also been fairly optimized for querying ORC tables.
  - Queries hitting PrestoDB will be slower than Kylin-answered queries. Query times vary primary depending on how much data is being queried, but response times may range from 5 seconds to multiple minutes.
  - Data must be processed into the ORC-backed Hive table for it to be part of PrestoDB's results, so results will typically lag 2-3 minutes behind live data (and therefore differ from Kylin results).
  - *TODO: Currently there's a 60 second timeout on PrestoDB queries to prevent long-running queries from piling up and hogging resources. However, if we find that people need to run longer-running queries, we can adjust this. We'll also need to adjust the default [60 second proxy timeouts](https://github.com/NREL/api-umbrella/blob/v0.11.0/config/default.yml#L21-L23).*
