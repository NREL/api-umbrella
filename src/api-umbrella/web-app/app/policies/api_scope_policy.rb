class ApiScopePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        query_scopes = []
        user.api_scopes_with_permission("admin_manage").each do |api_scope|
          query_scopes << {
            :host => api_scope.host,
            :path_prefix => api_scope.path_prefix_matcher,
          }
        end

        if(query_scopes.any?)
          scope.or(query_scopes)
        else
          scope.none
        end
      end
    end
  end

  def show?
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      api_scopes = user.api_scopes_with_permission("admin_manage")
      allowed = api_scopes.any? do |api_scope|
        (record.host == api_scope.host && api_scope.path_prefix_matcher.match(record.path_prefix))
      end
    end

    allowed
  end

  def update?
    show?
  end

  def create?
    update?
  end

  def destroy?
    update?
  end
end
