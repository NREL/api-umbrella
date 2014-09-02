object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admin_groups.count }
node(:recordsFiltered) { @admin_groups.count }
node :data do
  @admin_groups.map do |admin_group|
    data = admin_group.serializable_hash

    if(admin_group.api_scopes.present?)
      data.merge!({
        "api_scope_display_names" => admin_group.api_scopes.map { |api_scope| api_scope.display_name },
        "permission_display_names" => admin_group.permissions.sorted.map { |permission| permission.name },
      })
    end

    data
  end
end
