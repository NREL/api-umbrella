FactoryBot.define do
  factory :log_item do
    api_key { "UfhkQUBgWQbJ0ZVqnJ4TvA7quGCZHYTFCXwSfOTQ" }
    request_accept_encoding { "*/*" }
    request_at { Time.now.utc }
    request_host { "127.0.0.1" }
    request_ip { "127.0.0.1" }
    request_ip_city { "Golden" }
    request_ip_country { "US" }
    request_ip_region { "CO" }
    request_method { "GET" }
    request_path { "/hello/" }
    request_scheme { "http" }
    request_query { { "foo" => "bar" } }
    request_size { 140 }
    request_url_query { "foo=bar" }
    request_user_agent { "ApacheBench/2.3" }
    request_user_agent_family { "AB (Apache Bench)" }
    request_user_agent_type { "Other" }
    response_age { 0 }
    response_content_length { 14 }
    response_content_type { "text/plain" }
    response_server { "nginx" }
    response_size { 243 }
    response_status { 200 }
    response_time { 3 }
    user_email { "test@example.com" }
    user_id { "4199b260-ae76-463f-8395-d30de09c1540" }
    user_registration_source { "web_admin" }

    factory :xss_log_item do
      api_backend_id { %("><script class="xss-test">alert("api_backend_id#{SecureRandom.hex(6)}");</script>) }
      api_backend_resolved_host { %("><script class="xss-test">alert("api_backend_resolved_host#{SecureRandom.hex(6)}");</script>) }
      api_backend_response_code_details { %("><script class="xss-test">alert("api_backend_response_code_details#{SecureRandom.hex(6)}");</script>) }
      api_backend_response_flags { %("><script class="xss-test">alert("api_backend_response_flags#{SecureRandom.hex(6)}");</script>) }
      request_accept { %("><script class="xss-test">alert("request_accept#{SecureRandom.hex(6)}");</script>) }
      request_accept_encoding { %("><script class="xss-test">alert("request_accept_encoding#{SecureRandom.hex(6)}");</script>) }
      request_connection { %("><script class="xss-test">alert("request_connection#{SecureRandom.hex(6)}");</script>) }
      request_content_type { %("><script class="xss-test">alert("request_content_type#{SecureRandom.hex(6)}");</script>) }
      request_host { %("><script class="xss-test">alert("request_host#{SecureRandom.hex(6)}");</script>) }
      request_ip { %("><script class="xss-test">alert("request_ip#{SecureRandom.hex(6)}");</script>) }
      request_ip_city { %("><script class="xss-test">alert("request_ip_city#{SecureRandom.hex(6)}");</script>) }
      request_ip_country { %("><script class="xss-test">alert("request_ip_country#{SecureRandom.hex(6)}");</script>) }
      request_ip_region { %("><script class="xss-test">alert("request_ip_region#{SecureRandom.hex(6)}");</script>) }
      request_method { %("><script class="xss-test">alert("request_method#{SecureRandom.hex(6)}");</script>) }
      request_origin { %("><script class="xss-test">alert("request_origin#{SecureRandom.hex(6)}");</script>) }
      request_path { %("><script class="xss-test">alert("request_path#{SecureRandom.hex(6)}");</script>) }
      request_query { { "foo" => %("><script class="xss-test">alert("request_query#{SecureRandom.hex(6)}");</script>) } }
      request_referer { %("><script class="xss-test">alert("request_referer#{SecureRandom.hex(6)}");</script>) }
      request_scheme { %("><script class="xss-test">alert("request_scheme#{SecureRandom.hex(6)}");</script>) }
      request_url_query { %("><script class="xss-test">alert("request_url_query#{SecureRandom.hex(6)}");</script>) }
      request_user_agent { %("><script class="xss-test">alert("request_user_agent#{SecureRandom.hex(6)}");</script>) }
      response_cache { %("><script class="xss-test">alert("response_cache#{SecureRandom.hex(6)}");</script>) }
      response_cache_flags { %("><script class="xss-test">alert("response_cache_flags#{SecureRandom.hex(6)}");</script>) }
      response_content_encoding { %("><script class="xss-test">alert("response_content_encoding#{SecureRandom.hex(6)}");</script>) }
      response_content_type { %("><script class="xss-test">alert("response_content_type#{SecureRandom.hex(6)}");</script>) }
      response_custom1 { %("><script class="xss-test">alert("response_custom1#{SecureRandom.hex(6)}");</script>) }
      response_custom2 { %("><script class="xss-test">alert("response_custom2#{SecureRandom.hex(6)}");</script>) }
      response_custom3 { %("><script class="xss-test">alert("response_custom3#{SecureRandom.hex(6)}");</script>) }
      response_server { %("><script class="xss-test">alert("response_server#{SecureRandom.hex(6)}");</script>) }
      response_transfer_encoding { %("><script class="xss-test">alert("response_transfer_encoding#{SecureRandom.hex(6)}");</script>) }
      user_email { %("><script class="xss-test">alert("user_email#{SecureRandom.hex(6)}");</script>) }
      user_id { %("><script class="xss-test">alert("user_id#{SecureRandom.hex(6)}");</script>) }
      user_registration_source { %("><script class="xss-test">alert("user_registration_source#{SecureRandom.hex(6)}");</script>) }
    end

    factory :google_log_item do
      request_host { "localhost" }
      request_path { "/google/hello/" }
    end
  end
end
