require "addressable/uri"

mongo = Moped::Session.new([ENV["MONGO"]])
mongo.use :developer_production

elastic = Stretcher::Server.new("http://10.10.10.2:9200", :logger => Logger.new("/tmp/blah2.log"))

users = {}

start_time = Time.utc(2013, 5, 18)
while start_time < Time.now
  end_time = start_time + 1.hour

  elastic_index = "api-umbrella-logs-#{start_time.to_date.iso8601}"
  puts "== #{start_time} - #{end_time} =="

  timer_begin = Time.now

  records = []

  start_id = Moped::BSON::ObjectId.from_time(start_time)
  end_id = Moped::BSON::ObjectId.from_time(end_time)
  count = 0
  mongo[:api_request_logs].find(:_id => { "$gte" => start_id, "$lt" => end_id }).sort(:_id => 1).each do |log|
    env = {}
    if(log["env"])
      env = MultiJson.load(log["env"])
    end

    data = {}
    data["_type"] = "log"
    data["request_at"] = log["requested_at"].xmlschema
    data["request_method"] = env["REQUEST_METHOD"]
    data["request_path"] = log["path"].gsub(/\.\w+$/, "")
    data["request_url"] = "http://developer.nrel.gov#{env["REQUEST_URI"]}"
    data["request_user_agent"] = env["HTTP_USER_AGENT"]
    data["request_accept_encoding"] = env["HTTP_ACCEPT_ENCODING"]
    data["request_ip"] = log["ip_address"]
    data["response_status"] = log["response_status"]
    data["response_content_type"] = Rack::Mime::MIME_TYPES[File.extname(log["path"])]
    data["api_key"] = log["api_key"]
    data["_id"] = Base64.urlsafe_encode64(Digest::SHA256.new.digest("#{data["url"]}#{log["requested_at"].to_f}")).chomp("=")

    if(data["api_key"])
      users[data["api_key"]] ||= mongo[:api_users].find(:api_key => data["api_key"]).first
      if users[data["api_key"]]
        data["user_id"] = users[data["api_key"]]["_id"]
      end
    end

    if(data["request_url"] =~ /api_key/)
      uri = Addressable::URI.parse(data["request_url"])
      query_values = uri.query_values
      if(query_values)
        uri.query_values = query_values.except("api_key")
        data["request_url"] = uri.to_s
      end
    end

    if(data["request_user_agent"])
      data["request_user_agent_family"] = UserAgent.parse(data["request_user_agent"]).browser
    end

    records << data

    if(records.length > 1000)
      elastic.index(elastic_index).bulk_index(records)
      records.clear
    end

    count += 1
  end

  if(records.any?)
    elastic.index(elastic_index).bulk_index(records)
    records.clear
  end

  duration = Time.now - timer_begin
  rate = count.to_f / duration.to_f
  puts "  #{Time.now}: Processed #{count} in: #{duration} seconds (#{rate} records/second)"
  timer_begin = Time.now

  start_time = end_time
end
