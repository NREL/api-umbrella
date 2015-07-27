require "support/vcr"

client = Elasticsearch::Client.new

# Fetch the elasticsearch template file from the router project. Cache it with
# VCR, but periodically re-record it to make sure we stay up-to-date.
VCR.use_cassette("elasticsearch_templates", :re_record_interval => 1.day) do
  templates = MultiJson.load(RestClient.get("https://raw.githubusercontent.com/NREL/api-umbrella-router/master/config/elasticsearch_templates.json"))
  templates.each do |template|
    client.indices.put_template({
      :name => template["id"],
      :body => template["template"],
    })
  end
end

# For simplicity sake, we're assuming our tests only deal with a few explicit
# indexes currently.
["2014-11", "2015-01", "2015-03"].each do |month|
  # First delete any existing indexes.
  ["api-umbrella-logs-v1-#{month}", "api-umbrella-logs-#{month}", "api-umbrella-logs-write-#{month}"].each do |index_name|
    begin
      client.indices.delete :index => index_name
    rescue Elasticsearch::Transport::Transport::Errors::NotFound # rubocop:disable Lint/HandleExceptions
    end
  end

  # Create the index with proper aliases setup.
  client.indices.create(:index => "api-umbrella-logs-v1-#{month}", :body => {
    :aliases => {
      "api-umbrella-logs-#{month}" => {},
      "api-umbrella-logs-write-#{month}" => {},
    },
  })
end
