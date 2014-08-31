object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admins.count }
node(:recordsFiltered) { @admins.count }
node :data do
  @admins.map do |admin|
    admin.serializable_hash(:force_except => [:authentication_token])
  end
end
