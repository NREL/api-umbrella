require "api_umbrella/attributify_data"
require "common_validations"

class Api
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Paranoia
  include Mongoid::Delorean::Trackable
  include Mongoid::EmbeddedErrors
  include ApiUmbrella::AttributifyData

  MAX_SORT_ORDER = 2_147_483_647
  MIN_SORT_ORDER = -2_147_483_648
  SORT_ORDER_GAP = 10_000

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String
  field :sort_order, :type => Integer
  field :backend_protocol, :type => String
  field :frontend_host, :type => String
  field :backend_host, :type => String
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
    :inclusion => { :in => ["http", "https"] }
  validates :frontend_host,
    :presence => true,
    :format => {
      :with => CommonValidations::HOST_FORMAT_WITH_WILDCARD,
      :message => :invalid_host_format,
    }
  validates :backend_host,
    :presence => true,
    :unless => proc { |record| record.frontend_host.start_with?("*") }
  validates :backend_host,
    :format => {
      :with => CommonValidations::HOST_FORMAT_WITH_WILDCARD,
      :message => :invalid_host_format,
    },
    :if => proc { |record| record.backend_host.present? }
  validates :balance_algorithm,
    :inclusion => { :in => ["round_robin", "least_conn", "ip_hash"] }
  validates_each :servers, :url_matches do |record, attr, value|
    if(value.blank? || (value && value.reject(&:marked_for_destruction?).blank?))
      record.errors.add(:base, "must have at least one #{attr}")
    end
  end

  # Callbacks
  before_save :calculate_sort_order
  after_save :handle_rate_limit_mode

  # Nested attributes
  accepts_nested_attributes_for :settings
  accepts_nested_attributes_for :servers, :url_matches, :sub_settings, :rewrites, :allow_destroy => true

  def self.sorted
    order_by(:sort_order.asc)
  end

  def attributes_hash
    self.attributes.to_h
  end

  def as_json(options = {})
    options[:methods] ||= []
    options[:methods] += [:error_data_yaml_strings, :headers_string, :default_response_headers_string, :override_response_headers_string]

    json = super(options)

    root = json
    if(options[:root])
      root = json[options[:root]]
    end

    root["creator"] = {
      "username" => (self.creator.username if(self.creator)),
    }

    root["updater"] = {
      "username" => (self.updater.username if(self.updater)),
    }

    json
  end

  def calculate_sort_order
    if(self.sort_order.blank?)
      self.move_to_end
    end

    true
  end

  def move_to_beginning
    order = 0

    # Find the current first sort_order value and move this record
    # SORT_ORDER_GAP before that value.
    first_api = Api.asc(:sort_order).first
    if(first_api)
      min_sort_order = first_api.sort_order
      if(min_sort_order.present?)
        order = min_sort_order - SORT_ORDER_GAP

        # If we've hit the minimum allowed value, find an new minimum value in
        # between.
        if(order < MIN_SORT_ORDER)
          order = ((min_sort_order + MIN_SORT_ORDER) / 2.0).floor
        end
      end
    end

    self.apply_sort_order(order)
  end

  def move_to_end
    order = 0

    # Find the current first sort_order value and move this record
    # SORT_ORDER_GAP after that value.
    last_api = Api.desc(:sort_order).first
    if(last_api)
      max_sort_order = last_api.sort_order
      if(max_sort_order.present?)
        order = max_sort_order + SORT_ORDER_GAP

        # If we've hit the maximum allowed value, find an new maximum value in
        # between.
        if(order > MAX_SORT_ORDER)
          order = ((max_sort_order + MAX_SORT_ORDER) / 2.0).ceil
        end
      end
    end

    self.apply_sort_order(order)
  end

  def move_after(after_api)
    order = nil

    # We're passed the API record we want to move the current record to be
    # after (after_api). Next, look for the record following after_api. This
    # determine the two records we want to try to sandwich the current record
    # between.
    after_after_api = Api.ne(:id => self.id).gt(:sort_order => after_api.sort_order).asc(:sort_order).first
    if(after_after_api)
      if(after_api.sort_order.present? && after_after_api.sort_order.present?)
        order = ((after_api.sort_order + after_after_api.sort_order) / 2.0)
        order = if(order < 0) then order.ceil else order.floor end
      end
    else
      # If we're trying to move the current record after the last record in the
      # database, then increment the sort order by SORT_ORDER_GAP.
      if(after_api.sort_order.present?)
        order = after_api.sort_order + SORT_ORDER_GAP
      end
    end

    # Make sure the order hasn't outside of the allowed integer bounds.
    if(order)
      if(order > MAX_SORT_ORDER)
        order = ((after_api.sort_order + MAX_SORT_ORDER) / 2.0).ceil
      elsif(order < MIN_SORT_ORDER)
        order = ((after_api.sort_order + MIN_SORT_ORDER) / 2.0).floor
      end
    end

    self.apply_sort_order(order)
  end

  def apply_sort_order(order)
    return unless(order)

    # Apply the new sort_order value first.
    self.sort_order = order
    unless(self.new_record?)
      self.update(:sort_order => order)
    end

    # Next look for any existing records that have conflicting sort_order
    # values. We will then shift those existing sort_order values to be unique.
    #
    # Note: This iterative, recursive approach isn't efficient, but since our
    # whole approach of having SORT_ORDER_GAP between each sort_order value,
    # conflicts like this should be exceedingly rare.
    conflicting_order_apis = Api.ne(:id => self.id).where(:sort_order => order)
    if(conflicting_order_apis.any?)
      # Shift positive rank_orders negatively, and negative rank_orders
      # positively. This is designed so that we work away from the
      # MAX_SORT_ORDER or MIN_SORT_ORDER values if we're bumping into our
      # integer size limits.
      conflicting_new_order = order - 1
      if(order < 0)
        conflicting_new_order = order + 1
      end

      conflicting_order_apis.each do |api|
        api.apply_sort_order(conflicting_new_order)
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

  def handle_transition_https_on_publish!
    if(self.settings)
      self.settings.set_transition_starts_on_publish
    end

    if(self.sub_settings)
      self.sub_settings.each do |sub|
        if(sub.settings)
          sub.settings.set_transition_starts_on_publish
        end
      end
    end

    if(self.changed?)
      self.save!
    end
  end

  def roles
    roles = []

    if(self.settings && self.settings.required_roles)
      roles += self.settings.required_roles
    end

    if(self.sub_settings)
      self.sub_settings.each do |sub|
        if(sub.settings && sub.settings.required_roles)
          roles += sub.settings.required_roles
        end
      end
    end

    roles.uniq!
    roles
  end

  def serializable_hash(options = nil)
    hash = super(options)
    # Ensure all embedded relationships are at least null in the JSON output
    # (rather than not being present), or else Ember-Data's serialization
    # throws warnings.
    hash["rewrites"] ||= nil
    hash["servers"] ||= nil
    hash["settings"] ||= nil
    hash["sub_settings"] ||= nil
    hash["url_matches"] ||= nil
    hash
  end

  def save(*args)
    # If a sub-settings record is being removed at the same time another
    # sub-setting record is being changed, this triggers a save failure, due to
    # how Mongoid saves the data. Similar to this issue:
    # https://jira.mongodb.org/browse/MONGOID-3964
    #
    # Since Mongoid doesn't handle this out of the box, we'll try to work
    # around the issue by first saving the changed records before the removes
    # happen as part of the normal save.
    if(self.valid? && self.sub_settings)
      self.sub_settings.each do |sub_setting|
        if(sub_setting.changed?)
          sub_setting.save!
        end
      end
    end

    super
  end
end
