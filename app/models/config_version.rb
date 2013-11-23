class ConfigVersion
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :version, :type => Time
  field :config, :type => Hash

  # Indexes
  index({ :version => 1 }, { :unique => true })

  def self.publish!
    self.create!({
      :version => Time.now,
      :config => self.current_config,
    })
  end

  def self.needs_publishing?
    change = self.last_change
    version = self.last_version
    if(!change || !version)
      true
    else
      (change > version)
    end
  end

  def self.last_version
    last = self.desc(:version).first
    if(last) then last.version else nil end
  end

  def self.last_change
    last = Api.desc(:updated_at).first
    if(last) then last.updated_at else nil end
  end

  def self.last_config
    last = self.desc(:version).first
    if(last) then last.config else nil end
  end

  def self.current_config
    {
      "apis" => Api.sorted.all.map { |api| Hash[api.attributes] }
    }
  end
end
