object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admins_count }
node(:recordsFiltered) { @admins_count }
node :data do
  @admins.map do |admin|
    data = admin.serializable_hash(:force_except => [:authentication_token])
    data.merge!({
      "group_names" => admin.group_names,
    })

    data
  end
end
