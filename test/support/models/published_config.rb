class PublishedConfig < ApplicationRecord
  self.table_name = "published_config"

  def self.active
    self.order("id DESC").first
  end

  def self.active_config
    active = self.active
    if(active) then active.config else nil end
  end

  def wait_until_live
    ApiUmbrellaTestHelpers::Process.instance.wait_for_config_version("db_config_version", self.id)
  end
end
