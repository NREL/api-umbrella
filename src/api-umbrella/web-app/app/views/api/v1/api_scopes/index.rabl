object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @api_scopes.count }
node(:recordsFiltered) { @api_scopes.count }
node :data do
  @api_scopes.map do |api_scope|
    api_scope.serializable_hash
  end
end
