object false

node(:sEcho) { params[:sEcho] }
node(:iTotalRecords) { @result.total }
node(:iTotalDisplayRecords) { @result.total }
node :aaData do
  @result.results.map do |log|
    log.except(:api_key, :_type, :_score, :_index).merge({
      :request_url => log.request_url.gsub(%r{^.*://[^/]*}, "")
    })

=begin
    [
      log._id,
      log.request_at,
      log.request_method,
      log.request_url,
      log.request_ip,
      log.response_status,
      log.response_content_length,
      log.response_content_type,
      log.response_age,
      log.internal_gatekeeper_time,
      log.internal_response_time,
      log.user_id,
      log.user_email,
      log.request_path,
      log.request_url.gsub(%r{^.*://[^/]*}, ""),
    ]
=end
  end
end
