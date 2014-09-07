class ApiUserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        if(user.can?("user_view"))
          scope.all
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
      if(user.can?("user_view"))
        allowed = true
      end
    end

    allowed
  end

  def update?
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      if(user.can?("user_manage"))
        allowed = true
      end

      if(allowed && record.roles.present?)
        allowed = record.roles.all? do |role|
          ApiUserRolePolicy.new(user, role).show?
        end
      end
    end

    allowed
  end

  def create?
    if(!user)
      true
    else
      update?
    end
  end
end
