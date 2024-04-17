require_relative "../../test_helper"

class Test::Proxy::Logging::TestHierarchy < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_exceeds_7_path_levels_deep
    response = Typhoeus.get("http://127.0.0.1:9080/api/logging-example/foo/bar/baz/qux/quux/quuux/quuuux/quuuuux/", log_http_options)
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    if $config["opensearch"]["template_version"] < 2
      assert_equal([
        "0/127.0.0.1:9080/",
        "1/127.0.0.1:9080/api/",
        "2/127.0.0.1:9080/api/logging-example/",
        "3/127.0.0.1:9080/api/logging-example/foo/",
        "4/127.0.0.1:9080/api/logging-example/foo/bar/",
        "5/127.0.0.1:9080/api/logging-example/foo/bar/baz/",
        "6/127.0.0.1:9080/api/logging-example/foo/bar/baz/qux/quux/quuux/quuuux/quuuuux",
      ], record["request_hierarchy"])
      refute(record.key?("request_url_hierarchy_level0"))
      refute(record.key?("request_url_hierarchy_level1"))
      refute(record.key?("request_url_hierarchy_level2"))
      refute(record.key?("request_url_hierarchy_level3"))
      refute(record.key?("request_url_hierarchy_level4"))
      refute(record.key?("request_url_hierarchy_level5"))
      refute(record.key?("request_url_hierarchy_level6"))
      refute(record.key?("request_url_hierarchy_level7"))
    else
      assert_equal("127.0.0.1:9080/", record.fetch("request_url_hierarchy_level0"))
      assert_equal("api/", record.fetch("request_url_hierarchy_level1"))
      assert_equal("logging-example/", record.fetch("request_url_hierarchy_level2"))
      assert_equal("foo/", record.fetch("request_url_hierarchy_level3"))
      assert_equal("bar/", record.fetch("request_url_hierarchy_level4"))
      assert_equal("baz/", record.fetch("request_url_hierarchy_level5"))
      assert_equal("qux/quux/quuux/quuuux/quuuuux", record.fetch("request_url_hierarchy_level6"))
      refute(record.key?("request_url_hierarchy_level7"))
      refute(record.key?("request_hierarchy"))
    end
  end
end
