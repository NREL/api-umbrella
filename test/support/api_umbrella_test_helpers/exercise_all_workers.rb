module ApiUmbrellaTestHelpers
  module ExerciseAllWorkers
    private

    def exercise_all_workers(path, options = {})
      unless(path.end_with?("/info/"))
        flunk("path for exercise_all_workers must end with '/info/'")
      end

      http_opts = http_options.deep_merge({
        :headers => {
          # Return debug information on the responses about which nginx
          # worker process was used for the request.
          "X-Api-Umbrella-Test-Debug-Workers" => "true",
          # Don't use keepalive connections. This helps hit all the worker
          # processes more quickly.
          "Connection" => "close",
        },
        :params => {
          :unique_test_id => unique_test_id,
        },
      }).deep_merge(options)

      responses = []
      ids_seen = Set.new
      pids_seen = Set.new
      begin
        Timeout.timeout(10) do
          loop do
            response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_opts)
            if(response.headers["x-api-umbrella-test-worker-id"])
              ids_seen << response.headers["x-api-umbrella-test-worker-id"]
            end
            if(response.headers["x-api-umbrella-test-worker-pid"])
              pids_seen << response.headers["x-api-umbrella-test-worker-pid"]
            end
            responses << response

            if(ids_seen.length == $config["nginx"]["workers"] && pids_seen.length >= $config["nginx"]["workers"])
              break
            end
          end
        end
      rescue Timeout::Error
        flunk("All nginx workers not hit. Expected workers: #{$config["nginx"]["workers"]} Worker IDs seen: #{ids_seen.to_a.inspect} Worker PIDs seen: #{pids_seen.to_a.inspect}")
      end

      assert_operator(responses.length, :>=, $config["nginx"]["workers"])
      responses
    end
  end
end
