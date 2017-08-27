class PublishedConfig < ApplicationRecord
  self.table_name = "published_config"

  def self.publish!(config)
    self.create!({
      :config => config,
    })
  end

  def self.active
    self.desc(:id).first
  end

  def self.active_config
    active = self.active
    if(active) then active.config else nil end
  end

  def self.pending_config
    {
      "apis" => Api.order_by(:sort_order.asc).all.map { |api| Hash[api.attributes] },
    }
  end

  def wait_until_live
    version = self.id
    ApiUmbrellaTestHelpers::Process.wait_for_config_version("db_config_version", id)
  end
end
