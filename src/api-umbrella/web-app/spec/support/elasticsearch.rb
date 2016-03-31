require "support/vcr"

RSpec.configure do |config|
  config.before(:suite) do
    client = Elasticsearch::Client.new({
      :hosts => ApiUmbrellaConfig[:elasticsearch][:hosts],
      :logger => Rails.logger
    })

    templates = MultiJson.load(File.read(File.expand_path("../../../../../../config/elasticsearch_templates.json", __FILE__)))
    templates.each do |template|
      client.indices.put_template({
        :name => template["id"],
        :body => template["template"],
      })
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
  end
end
