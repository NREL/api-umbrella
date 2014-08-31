class AdminGroupPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        scope_ids = []
        user.groups_with_access("admin_manage").each do |group|
          scope_ids << group.scope_id
        end

        scope.in(:scope_id => scope_ids)
      end
    end
  end

  def show?
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      user.groups_with_access("admin_manage").each do |current_user_group|
        allowed = (current_user_group.scope_id == record.scope_id)
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
