module ApiUmbrellaTestHelpers
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
      flunk("Background job was not processed within expected time. Is delayed_job running?")
    end

    def delayed_job_sent_messages
      wait_for_delayed_jobs
      response = Typhoeus.get("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
      assert_response_code(200, response)
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
