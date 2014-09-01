class ConfigVersion
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :version, :type => Time
  field :config, :type => Hash

  # Indexes
  index({ :version => 1 }, { :unique => true })

  def self.publish!(config)
    self.create!({
      :version => Time.now,
      :config => config,
    })
  end

  def self.needs_publishing?
    last_change_at = self.last_change_at
    active_version_time = self.active_version
    if(!last_change_at || !active_version_time)
      true
    else
      (last_change_at > active_version_time)
    end
  end

  def self.active
    self.desc(:version).first
  end

  def self.active_version
    active = self.active
    if(active) then active.version else nil end
  end

  def self.last_change_at
    last = Api.desc(:updated_at).first
    if(last) then last.updated_at else nil end
  end

  def self.active_config
    active = self.active
    if(active) then active.config else nil end
  end

  def self.pending_config
    {
      "apis" => Api.sorted.all.map { |api| Hash[api.attributes] }
    }
  end

  def self.pending_changes(current_admin)
    # Grab all APIs, including "deleted" ones so we can determine what API
    # deletions still need to be published.
    pending_apis = Api.unscoped

    if(current_admin)
      pending_apis = Pundit.policy_scope!(current_admin, pending_apis)
    end

    pending_apis = pending_apis.sorted.all
    pending_apis = pending_apis.to_a.select { |api| Pundit.policy!(current_admin, api).publish? }
    pending_apis.map! { |api| api.attributes_hash }

    active_config = ConfigVersion.active_config

    changes = {
      :new => [],
      :modified => [],
      :deleted => [],
      :identical => [],
    }

    active_apis_by_id = {}
    if(active_config.present? || active_config["apis"].present?)
      active_config["apis"].each do |active_api|
        active_apis_by_id[active_api["_id"]] = active_api
      end
    end

    pending_apis.each do |pending_api|
      active_api = active_apis_by_id[pending_api["_id"]]

      if(pending_api["deleted_at"].present?)
        if(active_api.present?)
          changes[:deleted] << {
            "mode" => "deleted",
            "active" => active_api,
            "pending" => nil,
          }
        end
      else
        if(active_api.blank?)
          changes[:new] << {
            "mode" => "new",
            "active" => nil,
            "pending" => pending_api,
          }
        elsif(api_for_comparison(active_api) == api_for_comparison(pending_api))
          changes[:identical] << {
            "mode" => "identical",
            "active" => active_api,
            "pending" => pending_api,
          }
        else
          changes[:modified] << {
            "mode" => "modified",
            "active" => active_api,
            "pending" => pending_api,
          }
        end
      end
    end

    changes.each do |mode, mode_changes|
      mode_changes.each do |change|
        change["id"] = if(change["pending"]) then change["pending"]["_id"] else change["active"]["_id"] end
        change["name"] = if(change["pending"]) then change["pending"]["name"] else change["active"]["name"] end
        change["active_yaml"] = pretty_dump(change["active"])
        change["pending_yaml"] = pretty_dump(change["pending"])
      end
    end

    changes
  end

  def self.api_for_comparison(data)
    # Don't look at timestamp/userstamp/versioning fields when comparing the
    # data to import, since these are likely to differ even if the data is
    # really the same (since these depend on when the import was actually
    # performed).
    data.except(*%w(version created_by created_at updated_at updated_by)) if(data)
  end

  def self.pretty_dump(data)
    yaml = ""
    if(data.present?)
      data = prettify_data(api_for_comparison(data))
      yaml = Psych.dump(data)
      yaml.gsub!(/^---\s*\n/, "")
    end

    yaml
  end

  def self.prettify_data(data)
    stringify_object_ids(sort_hash_by_keys(data))
  end

  def self.stringify_object_ids(object)
    duplicate = if(object.duplicable?) then object.dup else object end

    if(duplicate.kind_of?(Hash))
      duplicate.each do |key, value|
        if(value.kind_of?(Moped::BSON::ObjectId))
          duplicate[key] = value.to_s
        else
          duplicate[key] = stringify_object_ids(value)
        end
      end
    elsif(duplicate.kind_of?(Array))
      duplicate.map! do |item|
        stringify_object_ids(item)
      end
    end

    duplicate
  end

  def self.sort_hash_by_keys(object)
    if(object.kind_of?(Hash))
      object.keys.sort { |x, y| x.to_s <=> y.to_s }.reduce({}) do |sorted, key|
        sorted[key] = sort_hash_by_keys(object[key])
        sorted
      end
    elsif(object.kind_of?(Array))
      object.map do |item|
        sort_hash_by_keys(item)
      end
    else
      object
    end
  end
end
