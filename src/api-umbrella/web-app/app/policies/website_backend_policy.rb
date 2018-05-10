class WebsiteBackendPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve(permission = "backend_manage")
      if(user.superuser?)
        scope.all
      else
        api_scopes = []
        if(permission == :any)
          api_scopes = user.api_scopes
        else
          api_scopes = user.api_scopes_with_permission(permission)
        end

        query_scopes = []
        api_scopes.each do |api_scope|
          if(api_scope.root?)
            query_scopes << {
              :frontend_host => api_scope.host,
            }
          end
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
    can?("backend_manage")
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
        (record.frontend_host == api_scope.host && api_scope.root?)
      end
    end

    allowed
  end
end
