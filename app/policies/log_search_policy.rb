class LogSearchPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      unless(user.superuser?)
        query_scopes = []
        user.api_scopes_with_permission("analytics").each do |api_scope|
          query_scopes << {
            :bool => {
              :must => [
                {
                  :term => {
                    :request_host => api_scope.host,
                  },
                },
                {
                  :prefix => {
                    :request_path => api_scope.path_prefix,
                  },
                }
              ],
            }
          }
        end

        scope.permission_scope!(query_scopes)
      end
    end
  end
end
