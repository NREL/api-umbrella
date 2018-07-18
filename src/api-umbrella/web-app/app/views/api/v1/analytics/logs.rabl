object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @result.total }
node(:recordsFiltered) { @result.total }
node :data do
  @result.documents.map do |log|
    filtered = log["_source"].except("api_key", "_type", "_score", "_index").merge({
      "request_url" => sanitized_url_path_and_query(log["_source"]),
      "request_url_query" => strip_api_key_from_query(log["_source"]["request_url_query"]),
    })

    if(filtered["request_query"] && filtered["request_query"]["api_key"])
      filtered["request_query"].delete("api_key")
    end

    filtered
  end
end
