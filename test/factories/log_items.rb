FactoryBot.define do
  factory :log_item do
    api_key "UfhkQUBgWQbJ0ZVqnJ4TvA7quGCZHYTFCXwSfOTQ"
    request_accept_encoding "*/*"
    request_at { Time.now.utc }
    request_hierarchy ["0/127.0.0.1/", "1/127.0.0.1/hello"]
    request_host "127.0.0.1"
    request_ip "127.0.0.1"
    request_ip_city "Golden"
    request_ip_country "US"
    request_ip_region "CO"
    request_method "GET"
    request_path "/hello/"
    request_query({ "foo" => "bar" })
    request_scheme "http"
    request_size 140
    request_url "http://127.0.0.1/hello/?foo=bar"
    request_url_query("foo=bar")
    request_user_agent "ApacheBench/2.3"
    request_user_agent_family "AB (Apache Bench)"
    request_user_agent_type "Other"
    response_age 0
    response_content_length 14
    response_content_type "text/plain"
    response_server "nginx"
    response_size 243
    response_status 200
    response_time 3
    user_email "test@example.com"
    user_id "4199b260-ae76-463f-8395-d30de09c1540"
    user_registration_source "web_admin"

    factory :xss_log_item do
      request_accept_encoding '"><script class="xss-test">alert("1");</script>'
      request_host '"><script class="xss-test">alert("2");</script>'
      request_ip_city '"><script class="xss-test">alert("3");</script>'
      request_ip_country '"><script class="xss-test">alert("4");</script>'
      request_ip_region '"><script class="xss-test">alert("5");</script>'
      request_path '"><script class="xss-test">alert("6");</script>'
      request_query({ "foo" => '"><script class="xss-test">alert("7");</script>' })
      request_url '"><script class="xss-test">alert("8");</script>'
      request_url_query '"><script class="xss-test">alert("8");</script>'
      request_user_agent '"><script class="xss-test">alert("9");</script>'
      response_content_type '"><script class="xss-test">alert("10");</script>'
      response_server '"><script class="xss-test">alert("11");</script>'
      user_email '"><script class="xss-test">alert("12");</script>'
      user_registration_source '"><script class="xss-test">alert("13");</script>'
    end

    factory :google_log_item do
      request_host "localhost"
      request_path "/google/hello/"
      request_hierarchy ["0/localhost/", "1/localhost/google/", "2/localhost/google/hello"]
    end
  end
end
