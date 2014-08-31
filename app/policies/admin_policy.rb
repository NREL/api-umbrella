class AdminPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        group_ids = []
        user.groups_with_access("admin_manage").each do |group|
          group_ids += AdminGroup.where(:scope_id => group.scope_id).map { |g| g.id }
        end

        scope.in(:group_id => group_ids)
      end
    end
  end

  def show?
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      user.groups_with_access("admin_manage").each do |current_user_group|
        allowed = record.groups.all? do |record_group|
          current_user_group.scope_id == record_group.scope_id
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
