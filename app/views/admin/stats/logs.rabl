object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @result.total }
node(:iTotalDisplayRecords) { @result.total }
node :aaData do
  @result.documents.map do |log|
    log.except("api_key", "_type", "_score", "_index").merge({
      "request_url" => log["request_url"].gsub(%r{^.*://[^/]*}, "")
    })
  end
end
