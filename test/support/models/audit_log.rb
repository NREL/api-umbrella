class AuditLog < ActiveRecord::Base
  self.table_name = "audit.log"
end
