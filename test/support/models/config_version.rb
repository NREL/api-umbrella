class ConfigVersion
  include Mongoid::Document
  include Mongoid::Timestamps
  field :version, :type => Time
  field :config, :type => Hash

  def self.publish!(config)
    self.create!({
      :version => Time.now.utc,
      :config => config,
    })
  end

  def self.active
    self.desc(:version).first
  end

  def self.active_config
    active = self.active
    if(active) then active.config else nil end
  end

  def self.pending_config
    {
      "apis" => Api.order_by(:sort_order.asc).all.map { |api| Hash[api.attributes] },
      "website_backends" => WebsiteBackend.order_by(:frontend_host.asc).all.map { |api| Hash[api.attributes] },
    }
  end

  def wait_until_live
    version = (self.version.to_f * 1000).to_i
    ApiUmbrellaTestHelpers::Process.wait_for_config_version("db_config_version", version)
  end
end
