object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @admins.count }
node(:iTotalDisplayRecords) { @admins.count }
node :aaData do
  @admins.map do |admin|
    admin.serializable_hash(:force_except => [:authentication_token])
  end
end
