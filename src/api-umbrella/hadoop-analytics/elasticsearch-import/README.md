```
$ cd hadoop-analytics
$ mvn clean package
$ sudo -u hive java -Dapiumbrella.page_size=10000 -Dapiumbrella.elasticsearch_url="http://ELASTICSEARCH_HOST:9200" -Dapiumbrella.hdfs_uri="hdfs://HDFS_HOST:8020" -Dapiumbrella.timezone=TIMEZONE -jar elasticsearch-import/target/elasticsearch-import-0.0.1-SNAPSHOT.jar

$ sudo -u hive hive
hive> CREATE DATABASE api_umbrella;
hive> CREATE EXTERNAL TABLE api_umbrella.logs(request_at BIGINT, id STRING, request_at_tz_offset INT, request_at_tz_hour SMALLINT, request_at_tz_minute SMALLINT, user_id STRING, denied_reason STRING, request_method STRING, request_url_scheme STRING, request_url_host STRING, request_url_port INT, request_url_path STRING, request_url_path_level1 STRING, request_url_path_level2 STRING, request_url_path_level3 STRING, request_url_path_level4 STRING, request_url_path_level5 STRING, request_url_path_level6 STRING, request_url_query STRING, request_ip STRING, request_ip_country STRING, request_ip_region STRING, request_ip_city STRING, request_ip_lat DOUBLE, request_ip_lon DOUBLE, request_user_agent STRING, request_user_agent_type STRING, request_user_agent_family STRING, request_size INT, request_accept STRING, request_accept_encoding STRING, request_content_type STRING, request_connection STRING, request_origin STRING, request_referer STRING, request_basic_auth_username STRING, response_status SMALLINT, response_content_type STRING, response_content_length INT, response_content_encoding STRING, response_transfer_encoding STRING, response_server STRING, response_cache STRING, response_age INT, response_size INT, timer_response DOUBLE, timer_backend_response DOUBLE, timer_internal DOUBLE, timer_proxy_overhead DOUBLE, log_imported BOOLEAN) PARTITIONED BY (request_at_tz_year SMALLINT, request_at_tz_month TINYINT, request_at_tz_week TINYINT, request_at_tz_date DATE) STORED AS ORC LOCATION '/apps/api-umbrella/logs';
hive> exit;
$ sudo -u hive hadoop fs -ls -R /apps/api-umbrella/logs | grep "\.orc$" | grep -o "[^ ]*$" | sort -V | sed -e "s/.*request_at_tz_year=\([0-9]\+\).*request_at_tz_month=\([0-9]\+\).*request_at_tz_week=\([0-9]\+\).*request_at_tz_date=\([0-9\-]\+\).*/ALTER TABLE api_umbrella.logs ADD IF NOT EXISTS PARTITION(request_at_tz_year=\1, request_at_tz_month=\2, request_at_tz_week=\3, request_at_tz_date='\4');/" > /tmp/api_umbrella_load_partitions.sql
$ sudo -u hive hive -f /tmp/api_umbrella_load_partitions.sql && rm /tmp/api_umbrella_load_partitions.sql

$ curl 'http://localhost:7070/kylin/api/tables/api_umbrella.logs/api_umbrella' -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{}'
$ echo '{"cubeDescData":"{
  \"name\": \"logs_cube\",
  \"description\": \"\",
  \"dimensions\": [
    {
      \"name\": \"REQUEST_AT_HIERARCHY\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": true,
      \"derived\": null,
      \"column\": [
        \"REQUEST_AT_YEAR\",
        \"REQUEST_AT_MONTH\",
        \"REQUEST_AT_DATE\",
        \"REQUEST_AT_HOUR\"
      ],
      \"id\": 1
    },
    {
      \"name\": \"REQUEST_URL_HIERARCHY\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": true,
      \"derived\": null,
      \"column\": [
        \"REQUEST_URL_HOST\",
        \"REQUEST_URL_PATH_LEVEL1\",
        \"REQUEST_URL_PATH_LEVEL2\",
        \"REQUEST_URL_PATH_LEVEL3\",
        \"REQUEST_URL_PATH_LEVEL4\",
        \"REQUEST_URL_PATH_LEVEL5\",
        \"REQUEST_URL_PATH_LEVEL6\"
      ],
      \"id\": 2
    },
    {
      \"name\": \"USER_ID\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": false,
      \"derived\": null,
      \"column\": [
        \"USER_ID\"
      ],
      \"id\": 3
    },
    {
      \"name\": \"REQUEST_IP\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": false,
      \"derived\": null,
      \"column\": [
        \"REQUEST_IP\"
      ],
      \"id\": 4
    },
    {
      \"name\": \"RESPONSE_STATUS_HIERARCHY\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": true,
      \"derived\": null,
      \"column\": [
        \"RESPONSE_STATUS\",
        \"DENIED_REASON\"
      ],
      \"id\": 5
    },
    {
      \"name\": \"REQUEST_METHOD\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": false,
      \"derived\": null,
      \"column\": [
        \"REQUEST_METHOD\"
      ],
      \"id\": 6
    },
    {
      \"name\": \"REQUEST_IP_GEO_HIERARCHY\",
      \"table\": \"API_UMBRELLA.LOGS\",
      \"hierarchy\": true,
      \"derived\": null,
      \"column\": [
        \"REQUEST_IP_COUNTRY\",
        \"REQUEST_IP_REGION\",
        \"REQUEST_IP_CITY\"
      ],
      \"id\": 7
    }
  ],
  \"measures\": [
    {
      \"id\": 1,
      \"name\": \"_COUNT_\",
      \"function\": {
        \"expression\": \"COUNT\",
        \"returntype\": \"bigint\",
        \"parameter\": {
          \"type\": \"constant\",
          \"value\": \"1\"
        }
      }
    },
    {
      \"id\": 2,
      \"name\": \"COUNT_DISTINCT_USER_ID\",
      \"function\": {
        \"expression\": \"COUNT_DISTINCT\",
        \"returntype\": \"hllc12\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"USER_ID\"
        }
      }
    },
    {
      \"id\": 3,
      \"name\": \"COUNT_DISTINCT_REQUEST_IP\",
      \"function\": {
        \"expression\": \"COUNT_DISTINCT\",
        \"returntype\": \"hllc12\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"REQUEST_IP\"
        }
      }
    },
    {
      \"id\": 4,
      \"name\": \"SUM_TIMER_RESPONSE\",
      \"function\": {
        \"expression\": \"SUM\",
        \"returntype\": \"decimal\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"TIMER_RESPONSE\"
        }
      }
    },
    {
      \"id\": 5,
      \"name\": \"MAX_REQUEST_AT\",
      \"function\": {
        \"expression\": \"MAX\",
        \"returntype\": \"bigint\",
        \"parameter\": {
          \"type\": \"column\",
          \"value\": \"REQUEST_AT\"
        }
      }
    }
  ],
  \"rowkey\": {
    \"rowkey_columns\": [
      {
        \"column\": \"REQUEST_AT_YEAR\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": true
      },
      {
        \"column\": \"REQUEST_AT_MONTH\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": true
      },
      {
        \"column\": \"REQUEST_AT_DATE\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": true
      },
      {
        \"column\": \"REQUEST_AT_HOUR\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_HOST\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL1\",
        \"length\": \"40\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL2\",
        \"length\": \"40\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL3\",
        \"length\": \"40\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL4\",
        \"length\": \"40\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL5\",
        \"length\": \"40\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_URL_PATH_LEVEL6\",
        \"length\": \"40\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"USER_ID\",
        \"length\": \"36\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_IP\",
        \"length\": \"45\",
        \"dictionary\": \"false\",
        \"mandatory\": false
      },
      {
        \"column\": \"RESPONSE_STATUS\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"DENIED_REASON\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_METHOD\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_IP_COUNTRY\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_IP_REGION\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      },
      {
        \"column\": \"REQUEST_IP_CITY\",
        \"length\": 0,
        \"dictionary\": \"true\",
        \"mandatory\": false
      }
    ],
    \"aggregation_groups\": [
      [
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
        \"DENIED_REASON\"
      ],
      [
        \"REQUEST_AT_HOUR\"
      ],
      [
        \"REQUEST_METHOD\"
      ],
      [
        \"REQUEST_IP_COUNTRY\",
        \"REQUEST_IP_REGION\",
        \"REQUEST_IP_CITY\"
      ]
    ]
  },
  \"notify_list\": [],
  \"capacity\": \"\",
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
              \"MAX_REQUEST_AT\"
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
  \"retention_range\": \"0\",
  \"project\": \"api_umbrella\",
  \"auto_merge_time_ranges\": [
    604800000,
    2419200000
  ],
  \"model_name\": \"logs_cube\"
}","modelDescData":"{
  \"name\": \"logs_cube\",
  \"fact_table\": \"API_UMBRELLA.LOGS\",
  \"lookups\": [],
  \"filter_condition\": \"\",
  \"capacity\": \"MEDIUM\",
  \"partition_desc\": {
    \"partition_date_column\": \"API_UMBRELLA.LOGS.REQUEST_AT_DATE\",
    \"partition_date_start\": 1281916800000,
    \"partition_type\": \"APPEND\",
    \"partition_date_format\": \"yyyy-MM-dd\"
  },
  \"last_modified\": 0
}","project":"api_umbrella"}' | perl -p -e 's/\n/\\n/' | curl -v -XPOST -H "Content-Type: application/json;charset=UTF-8" --data-binary @- "http://ADMIN:KYLIN@localhost:7070/kylin/api/cubes" 
```
