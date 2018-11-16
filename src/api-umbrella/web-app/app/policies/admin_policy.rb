class AdminPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        api_scope_ids = []
        user.nested_api_scopes_with_permission("admin_manage").each do |api_scope|
          api_scope_ids << api_scope.id
        end

        group_ids = AdminGroup.in(:api_scope_ids => api_scope_ids).map { |g| g.id }

        if(group_ids.any?)
          scope.in(:group_ids => group_ids)
        else
          scope.none
        end
      end
    end
  end

  def show?
    # Allow admins to always view their own record, even if they don't have the
    # admin_manage privilege (so they can view their admin token).
    #
    # TODO: An admin should also be able to update their own password if using
    # local password authentication, but that is not yet implemented.
    manage? || (user.id == record.id)
  end

  def update?
    manage?
  end

  def create?
    update?
  end

  def destroy?
    update?
  end

  private

  def manage?
    allowed = false
    if(user.superuser?)
      allowed = true
    elsif(record.superuser?)
      allowed = false
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
end
