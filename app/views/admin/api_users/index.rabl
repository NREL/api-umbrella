object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @api_users.count }
node(:iTotalDisplayRecords) { @api_users.count }
node :aaData do
  @api_users.map do |api_user|
    data = api_user.serializable_hash.except("api_key").merge({
      "api_key_preview" => api_user.api_key.truncate(11)
    })

    if(api_user.created_by == current_admin.id && api_user.created_at >= (Time.now - 10.minutes))
      data.merge({
        "api_key" => api_user.api_key,
      })
    end

    data
  end
end
