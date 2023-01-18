module ApiUmbrellaTestHelpers
  module LoadBalancing
    private

    def make_load_balancing_requests(count)
      stats = {
        :hosts => {},
        :local_interface_ips => {},
      }

      hydra = Typhoeus::Hydra.new
      requests = Array.new(count) do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options)
        hydra.queue(request)
        request
      end
      hydra.run

      requests.each do |request|
        assert_response_code(200, request.response)
        data = MultiJson.load(request.response.body)

        ip = data.fetch("local_interface_ip")
        assert(ip)
        stats[:local_interface_ips][ip] ||= 0
        stats[:local_interface_ips][ip] += 1

        host = data.fetch("headers").fetch("host")
        assert(host)
        stats[:hosts][host] ||= 0
        stats[:hosts][host] += 1
      end

      stats
    end
  end
end
