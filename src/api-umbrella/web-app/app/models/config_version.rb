class ConfigVersion
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :version, :type => Time
  field :config, :type => Hash

  # Indexes
  # This model's indexes are managed by the Mongoose model inside the
  # api-umbrella-config project.
  # index({ :version => 1 }, { :unique => true })

  def self.publish!(config)
    self.create!({
      :version => Time.now.utc,
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
    if(active) then active.config else {} end
  end

  def self.pending_config
    {
      "apis" => Api.sorted.all.map { |api| api.attributes.to_h },
    }
  end

  def self.pending_changes(current_admin)
    changes = {
      "apis" => {},
      "website_backends" => {},
    }

    changes.each do |category, category_changes|
      # Grab all APIs, including "deleted" ones so we can determine what API
      # deletions still need to be published.
      pending_records = case(category)
      when "apis"
        Api.unscoped
      when "website_backends"
        WebsiteBackend.unscoped
      end

      if(current_admin)
        if(category == "website_backends")
          pending_records = WebsiteBackendPolicy::Scope.new(current_admin, pending_records).resolve("backend_publish")
        else
          pending_records = ApiPolicy::Scope.new(current_admin, pending_records).resolve("backend_publish")
        end
      end

      pending_records = pending_records.sorted.all
      pending_records = pending_records.to_a.select { |record| Pundit.policy!(current_admin, record).publish? }
      pending_records.map! { |record| record.attributes_hash }

      active_config = ConfigVersion.active_config

      category_changes.merge!({
        :new => [],
        :modified => [],
        :deleted => [],
        :identical => [],
      })

      active_records_by_id = {}
      if(active_config.present? && active_config[category].present?)
        active_config[category].each do |active_record|
          active_records_by_id[active_record["_id"]] = active_record
        end
      end

      pending_records.each do |pending_record|
        active_record = active_records_by_id[pending_record["_id"]]

        if(pending_record["deleted_at"].present?)
          if(active_record.present?)
            category_changes[:deleted] << {
              "mode" => "deleted",
              "active" => active_record,
              "pending" => nil,
            }
          end
        else
          if(active_record.blank?)
            category_changes[:new] << {
              "mode" => "new",
              "active" => nil,
              "pending" => pending_record,
            }
          elsif(record_for_comparison(active_record) == record_for_comparison(pending_record))
            category_changes[:identical] << {
              "mode" => "identical",
              "active" => active_record,
              "pending" => pending_record,
            }
          else
            category_changes[:modified] << {
              "mode" => "modified",
              "active" => active_record,
              "pending" => pending_record,
            }
          end
        end
      end

      category_changes.each_value do |mode_changes|
        mode_changes.each do |change|
          change["id"] = if(change["pending"]) then change["pending"]["_id"] else change["active"]["_id"] end
          change["name"] = case(category)
          when "apis"
            if(change["pending"]) then change["pending"]["name"] else change["active"]["name"] end
          when "website_backends"
            if(change["pending"]) then change["pending"]["frontend_host"] else change["active"]["frontend_host"] end
          end
          change["active_yaml"] = pretty_dump(change["active"])
          change["pending_yaml"] = pretty_dump(change["pending"])
        end
      end
    end

    changes
  end

  def self.record_for_comparison(object)
    duplicate = if(object.duplicable?) then object.dup else object end

    if(duplicate.kind_of?(Hash))
      # Don't look at timestamp/userstamp/versioning fields when comparing the
      # data to import, since these are likely to differ even if the data is
      # really the same (since these depend on when the import was actually
      # performed).
      duplicate.except!("version", "created_by", "created_at", "deleted_at", "updated_at", "updated_by", "_id")

      duplicate.each do |key, value|
        duplicate[key] = record_for_comparison(value)
      end
    elsif(duplicate.kind_of?(Array))
      duplicate.map! do |item|
        record_for_comparison(item)
      end
    end

    duplicate
  end

  def self.pretty_dump(data)
    yaml = ""
    if(data.present?)
      data = prettify_data(record_for_comparison(data))
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
        if(value.kind_of?(BSON::ObjectId))
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
      object.keys.sort_by(&:to_s).each_with_object({}) do |key, sorted|
        sorted[key] = sort_hash_by_keys(object[key])
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
