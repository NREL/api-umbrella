# Analytics Storage Adapters

API Umbrella can store analytics data in different types of databases, depending on your performance needs and volume of metrics. The adapter can be picked by setting the `analytics.adapter` option inside the `/etc/api-umbrella/api-umbrella.yml` configuration file.

## Elasticsearch

`analytics.adapter: elasticsearch`

- Currently the default analytics store.
- Suitable for small to medium amounts of historical analytics data. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*
- API Umbrella ships with with a default ElasticSearch database that can be used, or any ElasticSearch 1.7 cluster can be used (API Umbrella is not currently compatible with ElasticSearch 2).

**Note:** This storage adapter will become deprecated in v0.13 of API Umbrella and will be removed in v0.14, unless there is interest in maintaining it.

## PostgreSQL

`analytics.adapter: postgresql`

**TODO: The PostgreSQL adapter doesn't currently exist, but should be completed before shipping the package releases of v0.12.**

- Will become the default analytics store in v0.13 of API Umbrella.
- Suitable for small amounts of historical analytics data. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*
- API Umbrella ships with a default PostgreSQL database that can be used, or any PostgreSQL 9 database can be used. 

### PostgreSQL: Columnar Storage

- Suitable for small to medium amounts of historical analytics data. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*

For better analytics performance with larger volumes of analytics data, you can continue to use the PostgreSQL adapter, but with a compatible column-based variant:

- [cstore_fdw](https://github.com/citusdata/cstore_fdw)
- [Amazon Redshift](https://aws.amazon.com/redshift/)

## Kylin

`analytics.adapter: kylin`

- Suitable for large amounts of historical analytics data. *(TODO: Provide more definitive guidance on what small/medium/large amounts are)*
- Requires a functional Hadoop environment compatible with Kylin 1.2 ([Hortonworks Data Platform (HDP) 2.2](http://hortonworks.com/products/releases/hdp-2-2/) is recommended).
- Requires Kafka (can be enabled as part of HDP).
- Requires the optional `api-umbrella-hadoop-analytics` package to be installed on the analytics database server. *(TODO: Link to hadoop-analytics package downloads once built)*
