class ApiUserRole
  def self.all
    user_roles = ApiUser.distinct(:roles)
    all_api_roles = Api.all.map { |api| api.roles }.flatten
    all = user_roles + all_api_roles
    all.uniq!
    all.reject! { |role| role.blank? }
    all.sort!

    all
  end
end
