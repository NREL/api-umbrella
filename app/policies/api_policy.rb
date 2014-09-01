class ApiPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        query_scopes = []
        user.groups_with_access("backend_manage").each do |group|
          query_scopes << {
            :frontend_host => group.scope.host,
            :"url_matches.frontend_prefix" => group.scope.path_prefix_matcher,
          }
        end

        scope.or(query_scopes)
      end
    end
  end

  def show?(access = "backend_manage")
    allowed = false
    if(user.superuser?)
      allowed = true
    else
      user.groups_with_access(access).each do |group|
        if(record.frontend_host == group.scope.host)
          allowed = record.url_matches.all? do |url_match|
            group.scope.path_prefix_matcher.match(url_match.frontend_prefix)
          end
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
    show?
  end

  def destroy?
    show?
  end

  def publish?
    show?("backend_publish")
  end
end
