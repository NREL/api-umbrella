class AdminGroupPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        api_scope_ids = []
        user.nested_api_scopes_with_permission("admin_manage").each do |api_scope|
          api_scope_ids << api_scope.id
        end

        if(api_scope_ids.any?)
          scope.in(:api_scope_ids => api_scope_ids)
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
      current_user_scope_ids = []
      user.nested_api_scopes_with_permission("admin_manage").each do |current_user_scope|
        current_user_scope_ids << current_user_scope.id
      end

      record_api_scope_ids = []
      record.api_scopes.each do |record_api_scope|
        record_api_scope_ids << record_api_scope.id
      end

      allowed = (record_api_scope_ids - current_user_scope_ids).empty?
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
