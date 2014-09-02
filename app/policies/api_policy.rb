class ApiPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        query_scopes = []
        user.api_scopes_with_permission("backend_manage").each do |api_scope|
          query_scopes << {
            :frontend_host => api_scope.host,
            :"url_matches.frontend_prefix" => api_scope.path_prefix_matcher,
          }
        end

        scope.or(query_scopes)
      end
    end
  end

  def show?(permission = "backend_manage")
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      user.api_scopes_with_permission(permission).each do |api_scope|
        if(record.frontend_host == api_scope.host)
          allowed = record.url_matches.all? do |url_match|
            api_scope.path_prefix_matcher.match(url_match.frontend_prefix)
          end
        end

        break if(allowed)
      end
    end

    allowed
  end

  def update?
    show?
  end

  def create?
    show?
  end

  def destroy?
    show?
  end

  def publish?
    show?("backend_publish")
  end
end
