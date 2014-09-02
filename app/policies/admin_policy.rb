class AdminPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        api_scope_ids = []
        user.api_scopes_with_permission("admin_manage").each do |api_scope|
          api_scope_ids << api_scope.id
        end

        group_ids = AdminGroup.in(:api_scope_ids => api_scope_ids).map { |g| g.id }
        scope.in(:group_id => group_ids)
      end
    end
  end

  def show?
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      user.api_scopes_with_permission("admin_manage").each do |current_user_scope|
        allowed = record.api_scopes.all? do |record_api_scope|
          current_user_scope.id == record_api_scope.id
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
    update?
  end
end
