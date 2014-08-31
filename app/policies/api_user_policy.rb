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
    show?
  end

  def create?
    true
  end
end
