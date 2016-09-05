class MoveCachedCityGeocodesToMongo < Mongoid::Migration
  def self.up
    client = Elasticsearch::Client.new({
      :hosts => ApiUmbrellaConfig[:elasticsearch][:hosts],
      :logger => Rails.logger,
    })

    result = client.search({
      :index => "api-umbrella",
      :type => "city",
      :search_type => "scan",
      :scroll => "2m",
      :size => 500,
    })

    while result = client.scroll(:scroll_id => result["_scroll_id"], :scroll => "2m") && !result["hits"]["hits"].empty? # rubocop:disable Lint/AssignmentInCondition
      result["hits"]["hits"].each do |hit|
        LogCityLocation.create!({
          :_id => hit["_id"],
          :country => hit["_source"]["country"],
          :region => hit["_source"]["region"],
          :city => hit["_source"]["city"],
          :location => {
            :type => "Point",
            :coordinates => [
              hit["_source"]["location"]["lon"],
              hit["_source"]["location"]["lat"],
            ],
          },
          :updated_at => Time.at(hit["_source"]["updated_at"] / 1000.0).utc,
        })
      end
    end
  end

  def self.down
    LogCityLocation.collection.drop
  end
end
