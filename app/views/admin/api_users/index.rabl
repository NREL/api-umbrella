object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @api_users.count }
node(:iTotalDisplayRecords) { @api_users.count }
node :aaData do
  @api_users.map do |api_user|
    api_user.serializable_hash(:except => [:api_key], :methods => [:api_key_preview])
  end
end
