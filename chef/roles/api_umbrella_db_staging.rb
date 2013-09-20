name "api_umbrella_db_staging"
description "A base role for API Umbrella database servers"

run_list([
  "role[api_umbrella_db_base]",
  "role[mongodb_replicaset]",
  "role[mongodb_staging]",
])
