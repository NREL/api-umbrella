class ApiSortOrdersWithGap < Mongoid::Migration
  def self.up
    apis = Api.sorted.all.to_a
    apis.each_with_index do |api, index|
      api.sort_order = index * Api::SORT_ORDER_GAP
      api.save!(:validate => false)
    end

    active_config = ConfigVersion.active
    if(active_config)
      active_config.config["apis"].each do |api_config|
        api = Api.find(api_config["_id"])
        if(api)
          api_config["sort_order"] = api.sort_order
        end
      end

      if(active_config.changed?)
        active_config.save!(:validate => false)
      end
    end
  end

  def self.down
  end
end
