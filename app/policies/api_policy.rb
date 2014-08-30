class ApiPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if(user.superuser?)
        scope.all
      else
        query_scopes = user.scopes.map do |scope|
          {
            :frontend_host => scope.host,
            :"url_matches.frontend_prefix" => scope.path_prefix_matcher,
          }
        end

        scope.or(query_scopes)
      end
    end
  end

  def show?
    allowed = false
    user.scopes.each do |scope|
      if(record.frontend_host == scope.host)
        allowed = record.url_matches.all? do |url_match|
          scope.path_prefix_matcher.match(url_match.frontend_prefix)
        end
      end

      break if(allowed)
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
