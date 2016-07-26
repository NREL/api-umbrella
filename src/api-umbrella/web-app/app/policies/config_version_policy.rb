class ConfigVersionPolicy < ApplicationPolicy
  def import?
    user.superuser?
  end

  def export?
    user.superuser?
  end
end
