class Api
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable
  include Mongoid::EmbeddedErrors

  # Fields
  field :_id, type: String, default: lambda { UUIDTools::UUID.random_create.to_s }
  field :name, :type => String
  field :sort_order, :type => Integer
  field :backend_protocol, :type => String
  field :frontend_host, :type => String
  field :backend_host, :type => String
  field :append_query_string, :type => String
  field :require_https, :type => Boolean
  field :required_roles, :type => Array
  field :balance_algorithm, :type => String

  # Relations
  embeds_one :settings, :class_name => "Api::Settings"
  embeds_many :servers, :class_name => "Api::Server"
  embeds_many :url_matches, :class_name => "Api::UrlMatch"
  embeds_many :sub_settings, :class_name => "Api::SubSettings"
  embeds_many :rewrites, :class_name => "Api::Rewrite"

  # Validations
  validates :name,
    :presence => true
  validates :backend_protocol,
    :inclusion => { :in => %w(http https) }
  validates :frontend_host,
    :presence => true
  validates :backend_host,
    :presence => true
  validates :balance_algorithm,
    :inclusion => { :in => %w(round_robin least_conn ip_hash) }

  # Callbacks
  after_save :handle_rate_limit_mode

  # Nested attributes
  accepts_nested_attributes_for :settings
  accepts_nested_attributes_for :servers, :url_matches, :sub_settings, :rewrites, :allow_destroy => true

  # Mass assignment security
  attr_accessible :name,
    :sort_order,
    :backend_protocol,
    :frontend_host,
    :backend_host,
    :balance_algorithm,
    :settings_attributes,
    :servers_attributes,
    :url_matches_attributes,
    :sub_settings_attributes,
    :rewrites_attributes,

  def self.sorted
    order_by(:sort_order.asc, :created_at.desc)
  end

  def as_json(options)
    options[:methods] ||= []
    options[:methods] += [:required_roles_string, :error_data_yaml_strings]

    super(options)
  end

  # Accept a hash of raw, nested data to update this API's attributes with.
  # This accepts data in the same form as `#attributes` outputs (and as the
  # data is stored), but transforms it into the format
  # `accepts_nested_attributes_for` expects.
  #
  # The basic steps this takes on incoming data:
  #
  # - Rename the keys used for relationship data (eg, from "url_matches" to
  #   "url_matches_attributes").
  # - Add "_destroy" attribute items for embedded records that are no longer
  #   present in the input (we assume our input data is a full representation
  #   of how the data should look).
  # - Sort embedded arrays in-place if a "sort_order" key is present.
  #
  # With mongo it's tempting to forgo the whole `accepts_nested_attributes_for`
  # style of doing things and just set all the hash data directly, but that
  # approach currently starts to break down for multi-level nested items (for
  # example, setting rate_limits on the emedded settings object).
  def nested_attributes=(data)
    data = data.deep_dup

    old_data = self.attributes
    attributify_data!(data, old_data)

    self.attributes = data
  end

  private

  def attributify_data!(data, old_data)
    attributify_settings!(data, old_data)

    %w(servers url_matches sub_settings rewrites).each do |collection_name|
      attributify_embeds_many!(data, collection_name, old_data)
    end
  end

  def attributify_settings!(data, old_data)
    data["settings_attributes"] = data.delete("settings") || {}

    settings_data = data["settings_attributes"]
    old_settings_data = old_data["settings"] if(old_data.present?)

    %w(headers rate_limits).each do |collection_name|
      attributify_embeds_many!(settings_data, collection_name, old_settings_data)
    end
  end

  def attributify_embeds_many!(data, collection_name, old_data)
    attribute_key = "#{collection_name}_attributes"
    data[attribute_key] = data.delete(collection_name) || []

    collection_old_data = []
    if(old_data.present? && old_data[collection_name].present?)
      collection_old_data = old_data[collection_name]
    end

    if(data[attribute_key].any?)
      # The virtual `sort_order` attribute will only be present if the data
      # has been resorted by the user. Otherwise, we can just accept the
      # incoming array order as correct.
      if(data[attribute_key].first["sort_order"].present?)
        data[attribute_key].sort_by! { |d| d["sort_order"] }
      end

      data[attribute_key].each { |d| d.delete("sort_order") }
    end

    # Since the data posted is a full representation of the api, it doesn't
    # contain the special `_destroy` attribute accepts_nested_attributes_for
    # expects for removed items (they'll just be missing). So we need to
    # manually fill in the items that have been destroyed.
    old_ids = collection_old_data.map { |d| d["_id"].to_s }
    new_ids = data[attribute_key].map { |d| d["_id"].to_s }

    deleted_ids = old_ids - new_ids
    deleted_ids.each do |id|
      data[attribute_key] << {
        "_id" => id,
        :_destroy => true,
      }
    end

    # Process all the Settings models stored off of individual SubSettings
    # records.
    if(collection_name == "sub_settings")
      data[attribute_key].each do |sub_attributes|
        sub_old_data = nil
        if(sub_attributes["_id"].present?)
          sub_old_data = collection_old_data.detect do |old|
            old["_id"] == sub_attributes["_id"]
          end
        end

        attributify_settings!(sub_attributes, sub_old_data)
      end
    end
  end

  # After the API is saved, clear out any left-over rate_limits for settings
  # where the rate limit mode is no longer "custom."
  #
  # Ideally this would be shifted to a before_validation callback inside the
  # Settings model (so we don't have to explicitly check both #settings and
  # each #sub_settings). However, this doesn't seem to be easily possible.
  # before_validation doesn't quite work because clearing an embedded has_many
  # fires an immediate database query
  # (https://github.com/mongoid/mongoid/issues/2935), but then the new
  # attributes from the api model end up setting it back to what it was.
  # Furthermore, an after_save callback inside the Settings model doesn't work,
  # since those aren't fired on embedded documents by default (and for some
  # reason turning on cascade_callbacks leads to stack level too deep errors).
  def handle_rate_limit_mode
    if(self.settings.present?)
      if(self.settings.rate_limit_mode != "custom")
        self.settings.rate_limits.clear
      end
    end

    if(self.sub_settings.present?)
      self.sub_settings.each do |sub|
        if(sub.settings.present? && sub.settings.rate_limit_mode != "custom")
          sub.settings.rate_limits.clear
        end
      end
    end

    true
  end
end
