class DistributedRateLimitCounter < ApplicationRecord
  # TODO: Remove "_temp" once done testing new rate limiting strategy in parallel.
  self.table_name = "distributed_rate_limit_counters_temp"
end
