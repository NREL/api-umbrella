class Admin::ConfigController < Admin::BaseController
  set_tab :config

  def show
    if(ConfigVersion.needs_publishing?)
      @published_config = self.class.pretty_dump(ConfigVersion.last_config)
      @new_config = self.class.pretty_dump(ConfigVersion.current_config)
    end
  end

  def create
    ConfigVersion.publish!

    flash[:success] = "Successfully published configuration... Changes should be live in a few seconds..."
    redirect_to(admin_config_publish_path)
  end

  private

  def self.pretty_dump(data)
    data = sort_hash_by_keys(data)
    stringify_object_ids!(data)

    YAML.dump(data)
  end

  def self.stringify_object_ids!(object)
    if(object.kind_of?(Hash))
      object.each do |key, value|
        if(value.kind_of?(Moped::BSON::ObjectId))
          object[key] = value.to_s
        else
          stringify_object_ids!(object[key])
        end
      end
    elsif(object.kind_of?(Array))
      object.map! do |item|
        stringify_object_ids!(item)
      end
    end
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
