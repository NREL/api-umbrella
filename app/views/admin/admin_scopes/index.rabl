object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @admin_scopes.count }
node(:iTotalDisplayRecords) { @admin_scopes.count }
node :aaData do
  @admin_scopes.map do |admin|
    admin.serializable_hash
  end
end
