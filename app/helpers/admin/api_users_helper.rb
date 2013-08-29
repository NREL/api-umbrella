module Admin::ApiUsersHelper
  def available_roles
    roles = ApiUser.existing_roles

    # If a user with a new role is being created and validation errors were
    # encountered, include that new role in the list of available roles.
    if(@api_user.roles.present?)
      roles += @api_user.roles
      roles.uniq!
    end

    roles
  end
end
