class ApiScopePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        scope.none
      end
    end
  end

  def show?
    user.superuser?
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
