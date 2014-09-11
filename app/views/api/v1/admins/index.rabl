object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admins.count }
node(:recordsFiltered) { @admins.count }
node :data do
  @admins.map do |admin|
    data = admin.serializable_hash(:force_except => [:authentication_token])
    data.merge!({
      "group_names" => admin.groups.map { |group| group.name },
    })

    data
  end
end
