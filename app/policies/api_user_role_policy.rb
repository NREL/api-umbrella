class ApiUserRolePolicy < ApplicationPolicy
  def show?
    allowed = false
    if(user.superuser?)
      allowed = true
    elsif(record.start_with?("api-umbrella"))
      allowed = false
    else
      unless(user.disallowed_roles.include?(record))
        allowed = true
      end
    end

    allowed
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
end
