class WebsiteBackendPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        api_scopes = user.api_scopes_with_permission("backend_manage")

        query_scopes = []
        api_scopes.each do |api_scope|
          if(api_scope.path_prefix.blank? || api_scope.path_prefix == "/")
            query_scopes << {
              :frontend_host => api_scope.host,
            }
          end
        end

        scope.or(query_scopes)
      end
    end
  end

  def show?
    can?("backend_manage")
  end

  def update?
    show?
  end

  def create?
    show?
  end

  def publish?
    can?("backend_publish")
  end

  private

  def can?(permission)
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      api_scopes = user.api_scopes_with_permission(permission)

      allowed = api_scopes.any? do |api_scope|
        (record.frontend_host == api_scope.host && (api_scope.path_prefix.blank? || api_scope.path_prefix == "/"))
      end
    end

    allowed
  end
end
