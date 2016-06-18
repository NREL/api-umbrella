```
# Import from ElasticSearch to HDFS ORC files.
$ cd hadoop-analytics
$ mvn clean package
$ sudo -u hive java -Dapiumbrella.page_size=10000 -Dapiumbrella.elasticsearch_url="http://ELASTICSEARCH_HOST:9200" -Dapiumbrella.hdfs_uri="hdfs://HDFS_HOST:8020" -Dapiumbrella.timezone=TIMEZONE -jar elasticsearch-import/target/elasticsearch-import-0.0.1-SNAPSHOT.jar

# Create the Hive table.
$ sudo -u hive hive
hive> CREATE DATABASE api_umbrella;
hive> CREATE EXTERNAL TABLE api_umbrella.logs(timestamp_utc BIGINT, id STRING, timestamp_tz_offset INT, timestamp_tz_hour STRING, timestamp_tz_minute STRING, user_id STRING, denied_reason STRING, request_method STRING, request_url_scheme STRING, request_url_host STRING, request_url_port INT, request_url_path STRING, request_url_path_level1 STRING, request_url_path_level2 STRING, request_url_path_level3 STRING, request_url_path_level4 STRING, request_url_path_level5 STRING, request_url_path_level6 STRING, request_url_query STRING, request_ip STRING, request_ip_country STRING, request_ip_region STRING, request_ip_city STRING, request_ip_lat DOUBLE, request_ip_lon DOUBLE, request_user_agent STRING, request_user_agent_type STRING, request_user_agent_family STRING, request_size INT, request_accept STRING, request_accept_encoding STRING, request_content_type STRING, request_connection STRING, request_origin STRING, request_referer STRING, request_basic_auth_username STRING, response_status SMALLINT, response_content_type STRING, response_content_length INT, response_content_encoding STRING, response_transfer_encoding STRING, response_server STRING, response_cache STRING, response_age INT, response_size INT, timer_response DOUBLE, timer_backend_response DOUBLE, timer_internal DOUBLE, timer_proxy_overhead DOUBLE, log_imported BOOLEAN) PARTITIONED BY (timestamp_tz_year DATE, timestamp_tz_month DATE, timestamp_tz_week DATE, timestamp_tz_date DATE) STORED AS ORC LOCATION '/apps/api-umbrella/logs';
hive> exit;

# Create the Kylin project and define the table data source.
$ curl 'http://ADMIN:KYLIN@localhost:7070/kylin/api/projects' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"api_umbrella","description":""}'
$ curl 'http://ADMIN:KYLIN@localhost:7070/kylin/api/tables/api_umbrella.logs/api_umbrella' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{}'

# WAIT... Wait for the Kylin cardinality job to complete before proceeding
# (progress is viewable in the kylin.log file). If you define the table source
# after importing all the partitions, then the cardinality job will take forever
# in Kylin. Since we don't actaully need the cardinality caclculations, we'll
# just ensure they run against an empty table.
#
# If this issue gets addressed, then we would have more control over the
# cardinality job, and wouldn't have to wait:
# https://issues.apache.org/jira/browse/KYLIN-1407

# Add all the daily partitions to the Hive table.
$ sudo -u hive hadoop fs -ls -R /apps/api-umbrella/logs | grep -E "(\.orc|000000_0)$" | grep -o "[^ ]*$" | sort -V | sed -e "s/.*timestamp_tz_year=\([0-9\-]\+\).*timestamp_tz_month=\([0-9\-]\+\).*timestamp_tz_week=\([0-9\-]\+\).*timestamp_tz_date=\([0-9\-]\+\).*/ALTER TABLE api_umbrella.logs ADD IF NOT EXISTS PARTITION(timestamp_tz_year='\1', timestamp_tz_month='\2', timestamp_tz_week='\3', timestamp_tz_date='\4');/" | uniq > /tmp/api_umbrella_load_partitions.sql
$ sudo -u hive hive -f /tmp/api_umbrella_load_partitions.sql

# Create the model.
$ echo '{"modelDescData":"{
  \"name\": \"logs_model\",
  \"description\": \"\",
  \"fact_table\": \"API_UMBRELLA.LOGS\",
  \"lookups\": [],
  \"filter_condition\": \"\",
  \"capacity\": \"MEDIUM\",
  \"dimensions\": [
    {
      \"table\": \"API_UMBRELLA.LOGS\",
      \"columns\": [
        \"TIMESTAMP_TZ_YEAR\",
        \"TIMESTAMP_TZ_MONTH\",
        \"TIMESTAMP_TZ_WEEK\",
        \"TIMESTAMP_TZ_DATE\",
        \"REQUEST_URL_HOST\",
        \"REQUEST_URL_PATH_LEVEL1\",
        \"REQUEST_URL_PATH_LEVEL2\",
        \"REQUEST_URL_PATH_LEVEL3\",
        \"REQUEST_URL_PATH_LEVEL4\",
        \"REQUEST_URL_PATH_LEVEL5\",
        \"REQUEST_URL_PATH_LEVEL6\",
        \"USER_ID\",
        \"REQUEST_IP\",
        \"RESPONSE_STATUS\",
        \"DENIED_REASON\",
        \"REQUEST_METHOD\",
        \"REQUEST_IP_COUNTRY\",
        \"REQUEST_IP_REGION\",
        \"REQUEST_IP_CITY\"
      ]
    }
  ],
  \"metrics\": [
    \"USER_ID\",
    \"REQUEST_IP\",
    \"TIMER_RESPONSE\",
    \"TIMESTAMP_UTC\"
  ],
  \"partition_desc\": {
    \"partition_date_column\": \"API_UMBRELLA.LOGS.TIMESTAMP_TZ_DATE\",
    \"partition_date_format\": \"yyyy-MM-dd\",
    \"partition_date_start\": null,
    \"partition_type\": \"APPEND\"
  },
  \"last_modified\": 0
}","project":"api_umbrella"}' | perl -p -e 's/\n/\\n/' | curl -v -XPOST -H "Content-Type: application/json;charset=UTF-8" --data-binary @- "http://ADMIN:KYLIN@localhost:7070/kylin/api/models"

# Create the cube.
$ echo '{"cubeDescData":"{
  \"name\": \"logs_cube\",
  \"model_name\": \"logs_model\",
  \"description\": \"\",
  \"dimensions\": [
    {
      \"name\": \"API_UMBRELLA.LOGS.USER_ID\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"USER_ID\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.DENIED_REASON\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"DENIED_REASON\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_METHOD\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_METHOD\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_HOST\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_HOST\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_PATH_LEVEL1\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_PATH_LEVEL1\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_PATH_LEVEL2\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_PATH_LEVEL2\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_PATH_LEVEL3\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_PATH_LEVEL3\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_PATH_LEVEL4\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_PATH_LEVEL4\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_PATH_LEVEL5\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_PATH_LEVEL5\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_URL_PATH_LEVEL6\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_URL_PATH_LEVEL6\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_IP\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_IP\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_IP_COUNTRY\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_IP_COUNTRY\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_IP_REGION\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_IP_REGION\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.REQUEST_IP_CITY\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"REQUEST_IP_CITY\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.RESPONSE_STATUS\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"RESPONSE_STATUS\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.TIMESTAMP_TZ_YEAR\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"TIMESTAMP_TZ_YEAR\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.TIMESTAMP_TZ_MONTH\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"TIMESTAMP_TZ_MONTH\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.TIMESTAMP_TZ_WEEK\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"TIMESTAMP_TZ_WEEK\",
      \"derived\": null
    },
    {
      \"name\": \"API_UMBRELLA.LOGS.TIMESTAMP_TZ_DATE\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"column\": \"TIMESTAMP_TZ_DATE\",
      \"derived\": null
    }
  ],
  \"measures\": [
    {
      \"name\": \"_COUNT_\",
      \"function\": {
        \"expression\": \"COUNT\",
        \"parameter\": {
          \"type\": \"constant\",
          \"value\": \"1\",
          \"next_parameter\": null
        },
        \"returntype\": \"bigint\"
      },
      \"dependent_measure_ref\": null
    },
    {
      \"name\": \"COUNT_DISTINCT_USER_ID\",
      \"function\": {
        \"expression\": \"COUNT_DISTINCT\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"USER_ID\",
          \"next_parameter\": null
        },
        \"returntype\": \"hllc12\"
      },
      \"dependent_measure_ref\": null
    },
    {
      \"name\": \"COUNT_DISTINCT_REQUEST_IP\",
      \"function\": {
        \"expression\": \"COUNT_DISTINCT\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"REQUEST_IP\",
          \"next_parameter\": null
        },
        \"returntype\": \"hllc12\"
      },
      \"dependent_measure_ref\": null
    },
    {
      \"name\": \"SUM_TIMER_RESPONSE\",
      \"function\": {
        \"expression\": \"SUM\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"TIMER_RESPONSE\",
          \"next_parameter\": null
        },
        \"returntype\": \"decimal\"
      },
      \"dependent_measure_ref\": null
    },
    {
      \"name\": \"MAX_TIMESTAMP_UTC\",
      \"function\": {
        \"expression\": \"MAX\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"TIMESTAMP_UTC\",
          \"next_parameter\": null
        },
        \"returntype\": \"bigint\"
      },
      \"dependent_measure_ref\": null
    }
  ],
  \"rowkey\": {
    \"rowkey_columns\": [
      {
        \"column\": \"TIMESTAMP_TZ_YEAR\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"TIMESTAMP_TZ_MONTH\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"TIMESTAMP_TZ_WEEK\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"TIMESTAMP_TZ_DATE\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"REQUEST_URL_HOST\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL1\",
        \"encoding\": \"fixed_length:40\"
      },
      {
        \"column\": \"DENIED_REASON\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"USER_ID\",
        \"encoding\": \"fixed_length:36\"
      },
      {
        \"column\": \"REQUEST_IP\",
        \"encoding\": \"fixed_length:45\"
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL2\",
        \"encoding\": \"fixed_length:40\"
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL3\",
        \"encoding\": \"fixed_length:40\"
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL4\",
        \"encoding\": \"fixed_length:40\"
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL5\",
        \"encoding\": \"fixed_length:40\"
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL6\",
        \"encoding\": \"fixed_length:40\"
      },
      {
        \"column\": \"REQUEST_IP_COUNTRY\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"REQUEST_IP_REGION\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"REQUEST_IP_CITY\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"RESPONSE_STATUS\",
        \"encoding\": \"dict\"
      },
      {
        \"column\": \"REQUEST_METHOD\",
        \"encoding\": \"dict\"
      }
    ]
  },
  \"hbase_mapping\": {
    \"column_family\": [
      {
        \"name\": \"f1\",
        \"columns\": [
          {
            \"qualifier\": \"m\",
            \"measure_refs\": [
              \"_COUNT_\",
              \"SUM_TIMER_RESPONSE\",
              \"MAX_TIMESTAMP_UTC\"
            ]
          }
        ]
      },
      {
        \"name\": \"f2\",
        \"columns\": [
          {
            \"qualifier\": \"m\",
            \"measure_refs\": [
              \"COUNT_DISTINCT_USER_ID\",
              \"COUNT_DISTINCT_REQUEST_IP\"
            ]
          }
        ]
      }
    ]
  },
  \"aggregation_groups\": [
    {
      \"includes\": [
        \"TIMESTAMP_TZ_YEAR\",
        \"TIMESTAMP_TZ_MONTH\",
        \"TIMESTAMP_TZ_WEEK\",
        \"TIMESTAMP_TZ_DATE\",
        \"REQUEST_URL_HOST\",
        \"REQUEST_URL_PATH_LEVEL1\",
        \"REQUEST_URL_PATH_LEVEL2\",
        \"REQUEST_URL_PATH_LEVEL3\",
        \"REQUEST_URL_PATH_LEVEL4\",
        \"REQUEST_URL_PATH_LEVEL5\",
        \"REQUEST_URL_PATH_LEVEL6\",
        \"USER_ID\",
        \"REQUEST_IP\",
        \"RESPONSE_STATUS\",
        \"DENIED_REASON\",
        \"REQUEST_METHOD\",
        \"REQUEST_IP_COUNTRY\",
        \"REQUEST_IP_REGION\",
        \"REQUEST_IP_CITY\"
      ],
      \"select_rule\": {
        \"hierarchy_dims\": [
          [
            \"REQUEST_URL_HOST\",
            \"REQUEST_URL_PATH_LEVEL1\",
            \"REQUEST_URL_PATH_LEVEL2\",
            \"REQUEST_URL_PATH_LEVEL3\",
            \"REQUEST_URL_PATH_LEVEL4\",
            \"REQUEST_URL_PATH_LEVEL5\",
            \"REQUEST_URL_PATH_LEVEL6\"
          ],
          [
            \"REQUEST_IP_COUNTRY\",
            \"REQUEST_IP_REGION\",
            \"REQUEST_IP_CITY\"
          ]
        ],
        \"mandatory_dims\": [
          \"TIMESTAMP_TZ_YEAR\",
          \"TIMESTAMP_TZ_MONTH\",
          \"TIMESTAMP_TZ_WEEK\",
          \"TIMESTAMP_TZ_DATE\"
        ],
        \"joint_dims\": [
          [
            \"USER_ID\",
            \"REQUEST_IP\"
          ]
        ]
      }
    }
  ],
  \"notify_list\": [],
  \"status_need_notify\": [],
  \"partition_date_start\": 1281916800000,
  \"auto_merge_time_ranges\": [
    604800000,
    2419200000
  ],
  \"retention_range\": 0,
  \"engine_type\": 2,
  \"storage_type\": 2
}","cubeName":"logs_cube","project":"api_umbrella","streamingCube":false}' | perl -p -e 's/\n/\\n/' | curl -v -XPOST -H "Content-Type: application/json;charset=UTF-8" --data-binary @- "http://ADMIN:KYLIN@localhost:7070/kylin/api/cubes"
```
