class Admin::ConfigController < Admin::BaseController
  set_tab :config

  before_filter :setup_import, :only => [:import_preview, :import]

  helper_method :simplify_import_data

  def show
    if(ConfigVersion.needs_publishing?)
      @published_config = self.class.prettify_data(ConfigVersion.last_config)
      @new_config = self.class.prettify_data(ConfigVersion.current_config)
    end
  end

  def create
    ConfigVersion.publish!

    flash[:success] = "Successfully published configuration... Changes should be live in a few seconds..."
    redirect_to(admin_config_publish_path)
  end

  def import_export
  end

  def export
    @published_config = self.class.pretty_dump(ConfigVersion.last_config)

    respond_to do |format|
      format.yaml { render(:text => @published_config) }
    end
  end

  def import_preview
  end

  def import
    @apis = []

    params[:import_new_api_ids] ||= []
    params[:import_modified_api_ids] ||= []
    params[:import_deleted_api_ids] ||= []

    # Build up Api objects for all new or modified records to first validate.
    validate_api_ids = params[:import_new_api_ids] + params[:import_modified_api_ids]
    validate_api_ids.each do |id|
      api = Api.new

      # Set all the raw data from the incoming record without mass-assignment
      # protection (so we can maintain things like IDs).
      api.assign_attributes(@uploaded_apis_by_id[id], :without_protection => true)

      # Overwrite the imported updated timestamp/userstamp fields to keep track
      # of when the import was performed and also allow
      # ConfigVersion.needs_publishing? to determine that data has changed.
      api.updated_at = Time.now
      api.updater = self.current_admin

      @apis << api
    end

    valid = @apis.all? { |api| api.valid? }
    if(valid)
      # To modify existing records, we'll actually delete and re-create the
      # entire record. This is so that we can persist the imported IDs on both
      # new and existing embedded documents.
      params[:import_modified_api_ids].each do |id|
        api = Api.find(id)
        api.destroy
      end

      # Save all the new and modified records.
      @apis.each do |api|
        api.save!
      end

      # Delete records marked for removal.
      params[:import_deleted_api_ids].each do |id|
        api = Api.find(id)
        api.destroy
      end

      flash[:success] = "Successfully imported configuration. Configuration still needs to be published to take effect."
      redirect_to(admin_config_publish_path)
    else
      render(:action => "import_preview")
    end
  end

  private

  def simplify_import_data(data)
    # Don't look at timestamp/userstamp/versioning fields when comparing the
    # data to import, since these are likely to differ even if the data is
    # really the same (since these depend on when the import was actually
    # performed).
    data.except(*%w(version created_by created_at updated_at updated_by))
  end

  def setup_import
    if(params[:file].blank? && params[:uploaded].blank?)
      flash[:error] = "You must select a file to import"
      redirect_to(admin_config_import_export_path)
      return false
    end

    if(params[:file].present?)
      @uploaded_raw = params[:file].read
    else
      @uploaded_raw = params[:uploaded]
    end

    begin
      @uploaded = SafeYAML.load(@uploaded_raw)
      @uploaded = self.class.prettify_data(@uploaded)
    rescue => error
      flash[:error] = "YAML parsing error: #{error.message}"
      redirect_to(admin_config_import_export_path)
      return false
    end

    @local = self.class.prettify_data(ConfigVersion.current_config)

    @local["apis"] ||= []
    @uploaded["apis"] ||= []

    @new_api_ids = []
    @modified_api_ids = []
    @deleted_api_ids = []
    @identical_api_ids = []

    local_ids = @local["apis"].map { |api| api["_id"] }
    uploaded_ids = @uploaded["apis"].map { |api| api["_id"] }

    @new_api_ids = uploaded_ids - local_ids
    @deleted_api_ids = local_ids - uploaded_ids

    @uploaded["apis"].each do |uploaded_api|
      local_api = @local["apis"].detect { |api| api["_id"] == uploaded_api["_id"] }
      if(local_api.present?)
        if(simplify_import_data(uploaded_api) == simplify_import_data(local_api))
          @identical_api_ids << uploaded_api["_id"]
        else
          @modified_api_ids << uploaded_api["_id"]
        end
      end
    end

    @local_apis_by_id = {}
    @uploaded_apis_by_id = {}

    @local["apis"].each { |api| @local_apis_by_id[api["_id"]] = api }
    @uploaded["apis"].each { |api| @uploaded_apis_by_id[api["_id"]] = api }
  end

  def self.pretty_dump(data)
    data = prettify_data(data)
    Psych.dump(data)
  end

  def self.prettify_data(data)
    data = sort_hash_by_keys(data)
    stringify_object_ids!(data)

    data
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
