class LogSearchPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      unless(user.superuser?)
        rules = []
        user.api_scopes_with_permission("analytics").each do |api_scope|
          rules << {
            "condition" => "AND",
            "rules" => [
              {
                "field" => "request_host",
                "operator" => "equal",
                "value" => api_scope.host.downcase,
              },
              {
                "field" => "request_path",
                "operator" => "begins_with",
                "value" => api_scope.path_prefix.downcase,
              },
            ],
          }
        end

        if(rules.any?)
          scope.permission_scope!({
            "condition" => "OR",
            "rules" => rules,
          })
        else
          scope.none!
        end
      end
    end
  end
end
