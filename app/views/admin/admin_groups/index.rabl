object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @admin_groups.count }
node(:iTotalDisplayRecords) { @admin_groups.count }
node :aaData do
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
