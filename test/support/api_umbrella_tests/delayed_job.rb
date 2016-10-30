module ApiUmbrellaTests
  module DelayedJob
    private

    def wait_for_delayed_jobs
      Timeout.timeout(10) do
        db = Mongoid.client(:default)
        loop do
          count = db[:delayed_backend_mongoid_jobs].count
          if(count == 0)
            break
          end

          sleep 0.1
        end
      end
    rescue Timeout::Error
      raise Timeout::Error, "Background job was not processed within expected time. Is delayed_job running?"
    end

    def delayed_job_sent_messages
      wait_for_delayed_jobs
      response = Typhoeus.get("http://127.0.0.1:13103/api/v1/messages")
      assert_equal(200, response.code, response.body)
      messages = MultiJson.load(response.body)

      messages.each do |message|
        if(message["MIME"] && message["MIME"]["Parts"])
          message["_mime_parts"] = {}
          message["MIME"]["Parts"].each do |part|
            content_type = part["Headers"]["Content-Type"]
            if(content_type && content_type.any?)
              message["_mime_parts"][content_type.first] = part
            end
          end
        end
      end
    end
  end
end
