object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @api_users.count }
node(:recordsFiltered) { @api_users.count }
node :data do
  @api_users.map do |api_user|
    api_user.serializable_hash(:except => [:api_key], :methods => [:api_key_preview])
  end
end
