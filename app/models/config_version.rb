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
      :config => {
        :apis => Api.asc(:sort_order).all.map { |api| api.attributes },
      }
    })
  end

  def self.needs_publishing?
    if(!self.last_change || !self.last_version)
      true
    else
      (self.last_change > self.last_version)
    end
  end

  def self.last_version
    unless @last_version
      last = self.desc(:version).first
      @last_version = if(last) then last.version else nil end
    end

    @last_version
  end

  def self.last_change
    unless @last_change
      last = Api.desc(:updated_at).first
      @last_change = if(last) then last.updated_at else nil end
    end

    @last_change
  end
end
