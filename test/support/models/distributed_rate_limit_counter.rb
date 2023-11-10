class DistributedRateLimitCounter < ApplicationRecord
  self.table_name = "distributed_rate_limit_counters"
end
