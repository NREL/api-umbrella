object false

node(:draw) { params[:draw].to_i }
node(:recordsTotal) { @result.total }
node(:recordsFiltered) { @result.total }
node :data do
  @result.documents.map do |log|
    log["_source"].except("api_key", "_type", "_score", "_index").merge({
      "request_url" => log["_source"]["request_url"].gsub(%r{^.*://[^/]*}, "")
    })
  end
end
