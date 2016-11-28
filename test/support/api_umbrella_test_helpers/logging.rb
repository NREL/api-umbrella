module ApiUmbrellaTestHelpers
  module Logging
    private

    def wait_for_log(unique_query_id, options = {})
      options[:min_result_count] ||= 1

      begin
        Timeout.timeout(15) do
          loop do
            result = LogItem.gateway.client.search({
              :q => %(request_query.unique_query_id:"#{unique_query_id}"),
            })

            if(result && result["hits"] && result["hits"]["total"] >= options[:min_result_count])
              return {
                :result => result,
                :hit => result["hits"]["hits"][0],
                :hit_source => result["hits"]["hits"][0]["_source"],
              }
            end

            sleep 0.1
          end
        end
      rescue Timeout::Error
        raise Timeout::Error, "Log not found: #{unique_query_id.inspect}"
      end
    end

    def assert_logs_base_fields(record, unique_query_id, user = nil)
      assert_kind_of(Numeric, record["request_at"])
      assert_match(/\A\d{13}\z/, record["request_at"].to_s)
      assert_kind_of(Array, record["request_hierarchy"])
      assert_operator(record["request_hierarchy"].length, :>=, 1)
      assert_equal("127.0.0.1:9080", record["request_host"])
      assert_match(/\A\d+\.\d+\.\d+\.\d+\z/, record["request_ip"])
      assert_equal("GET", record["request_method"])
      assert_kind_of(String, record["request_path"])
      assert_operator(record["request_path"].length, :>=, 1)
      assert_kind_of(Hash, record["request_query"])
      assert_operator(record["request_query"].length, :>=, 1)
      assert_equal(unique_query_id, record["request_query"]["unique_query_id"])
      assert_equal("http", record["request_scheme"])
      assert_kind_of(Numeric, record["request_size"])
      assert_kind_of(String, record["request_url"])
      assert_equal(true, record["request_url"].start_with?("http://127.0.0.1:9080/"), record["request_url"])
      assert_kind_of(Numeric, record["response_size"])
      assert_kind_of(Numeric, record["response_status"])
      assert_kind_of(Numeric, record["response_time"])
      assert_kind_of(Numeric, record["internal_gatekeeper_time"])
      assert_kind_of(Numeric, record["proxy_overhead"])

      if(user)
        assert_equal(user.api_key, record["api_key"])
        assert_equal(user.email, record["user_email"])
        assert_equal(user.id, record["user_id"])
        assert_equal("seed", record["user_registration_source"])
      end
    end

    def assert_logs_backend_fields(record)
      assert_kind_of(Numeric, record["backend_response_time"])
    end

    def refute_logs_backend_fields(record)
      refute(record["backend_response_time"])
    end
  end
end
