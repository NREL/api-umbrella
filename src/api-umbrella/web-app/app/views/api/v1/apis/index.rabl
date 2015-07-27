object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @apis_count }
node(:recordsFiltered) { @apis_count }
node :data do
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
