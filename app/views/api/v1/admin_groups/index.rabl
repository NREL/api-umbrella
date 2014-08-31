object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admin_groups.count }
node(:recordsFiltered) { @admin_groups.count }
node :data do
  @admin_groups.map do |admin_group|
    data = admin_group.serializable_hash

    if(admin_group.scope.present?)
      data.merge!({
        "scope_display_name" => admin_group.scope.display_name
      })
    end

    data
  end
end
