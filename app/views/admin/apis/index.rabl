object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @apis.count }
node(:iTotalDisplayRecords) { @apis.count }
node :aaData do
  @apis.map do |api|
    data = api.serializable_hash

    if(api.url_matches.present?)
      data.merge!({
        "frontend_prefixes" => api.url_matches.map { |url_match| url_match.frontend_prefix }.join(", "),
      })
    end

    data
  end
end
