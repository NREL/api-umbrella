object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @admin_scopes.count }
node(:recordsFiltered) { @admin_scopes.count }
node :data do
  @admin_scopes.map do |admin_scope|
    admin_scope.serializable_hash
  end
end
