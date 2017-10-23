require "api_umbrella/attributify_data"

class ApiUser
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Paranoia
  include Mongoid::Delorean::Trackable
  include Mongoid::EmbeddedErrors
  include ApiUmbrella::AttributifyData

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :api_key
  field :first_name
  field :last_name
  field :email
  field :email_verified, :type => Boolean
  field :website
  field :use_description
  field :registration_source
  field :throttle_by_ip, :type => Boolean
  field :disabled_at, :type => Time
  field :roles, :type => Array
  field :registration_ip
  field :registration_user_agent
  field :registration_referer
  field :registration_origin

  # Virtual fields
  attr_accessor :terms_and_conditions

  # Relations
  embeds_one :settings, :class_name => "Api::Settings"

  # Indexes
  # This model's indexes are managed by the Mongoose model inside the
  # api-umbrella-gatekeeper project.
  # index({ :api_key => 1 }, { :unique => true })

  # Validations
  #
  # Provide full sentence validation errors. This doesn't really vibe with how
  # Rails intends to do things by default, but the we're super picky about
  # wording of things on the AFDC site which uses these messages. MongoMapper
  # and ActiveResource combined don't give great flexibility for error message
  # handling, so we're stuck with full sentences and changing how the errors
  # are displayed.
  validates :api_key,
    :uniqueness => true
  validates :first_name,
    :presence => { :message => "Provide your first name." },
    :format => { :without => proc { ::Regexp.new(ApiUmbrellaConfig[:web][:api_user][:first_name_exclude_regex], ::Regexp::IGNORECASE) } },
    :length => { :maximum => 80 }
  validates :last_name,
    :presence => { :message => "Provide your last name." },
    :format => { :without => proc { ::Regexp.new(ApiUmbrellaConfig[:web][:api_user][:last_name_exclude_regex], ::Regexp::IGNORECASE) } },
    :length => { :maximum => 80 }
  validates :email,
    :presence => { :message => "Provide your email address." },
    :format => {
      :with => /.+@.+\..+/,
      :allow_blank => true,
      :message => "Provide a valid email address.",
    },
    :length => { :maximum => 255 }
  validates :website,
    :format => {
      :with => /\w+\.\w+/,
      :message => "Your website must be a valid URL in the form of http://example.com",
    },
    :length => { :maximum => 255 },
    :allow_blank => true
  validates :terms_and_conditions,
    :acceptance => {
      :message => "Check the box to agree to the terms and conditions.",
      :accept => true,
    },
    :on => :create,
    :allow_nil => false

  # Callbacks
  before_validation :normalize_terms_and_conditions
  after_save :handle_rate_limit_mode
  after_save :touch_server_side_timestamp

  # Ensure the api key is generated (even if validations are disabled)
  before_validation :generate_api_key, :on => :create
  before_create :generate_api_key

  # Nested attributes
  accepts_nested_attributes_for :settings

  def self.human_attribute_name(attribute, options = {})
    case(attribute.to_sym)
    when :email
      "Email"
    when :terms_and_conditions
      "Terms and conditions"
    when :website
      "Web site"
    else
      super
    end
  end

  def as_json(*args)
    hash = super(*args)

    if(!self.valid?)
      hash.merge!(:errors => self.errors.full_messages)
    end

    hash
  end

  def enabled
    self.disabled_at.nil?
  end

  def enabled=(enabled)
    if(enabled.to_s == "false")
      if(self.disabled_at.nil?)
        self.disabled_at = Time.now.utc
      end
    else
      self.disabled_at = nil
    end
  end

  def api_key_preview
    self.api_key.truncate(9)
  end

  def api_key_hides_at
    @api_key_hides_at ||= self.created_at + 2.weeks
  end

  def serializable_hash(options = nil)
    hash = super(options)
    # Ensure all embedded relationships are at least null in the JSON output
    # (rather than not being present), or else Ember-Data's serialization
    # throws warnings.
    hash["settings"] ||= nil
    hash
  end

  private

  def normalize_terms_and_conditions
    # Handle the acceptance validation regardless of if it comes from the JSON
    # api (true values) or from an HTML form ('1' values).
    self.terms_and_conditions = (self.terms_and_conditions == true || self.terms_and_conditions == '1')
    true
  end

  def generate_api_key
    unless self.api_key
      # Generate a key containing A-Z, a-z, and 0-9 that's 40 chars in
      # length.
      key = ""
      while key.length < 40
        key = SecureRandom.base64(50).delete("+/=")[0, 40]
      end

      self.api_key = key
    end
  end

  # After the API is saved, clear out any left-over rate_limits for settings
  # where the rate limit mode is no longer "custom."
  #
  # Ideally this would be an after_save callback inside the Settings model, but
  # turning on cascade_callbacks seems to lead to tack level too deep errors.
  def handle_rate_limit_mode
    if(self.settings.present?)
      if(self.settings.rate_limit_mode != "custom")
        self.settings.rate_limits.clear
      end
    end

    true
  end

  # After making any change, fire an additional query to update the record's
  # "ts" field with the server-side timestamp. This ensures the timestamps are
  # set on the server and therefore not subject to clock drift on different
  # clients. This is important for us, since we use "ts" to detect when changes
  # have been made to the user collection for detecting changes and clearing
  # caches in the proxy part of the app.
  #
  # Ideally we'd make this part of single atomic upsert operation for the
  # document's actual create/update. However, an earlier attempt to override
  # the #save method to do this as a single operation led to issues, since it
  # was hard to replicate Mongoid's handling for embedded documents flagged for
  # destruction. But since the actual timestamps on these aren't very
  # important, performing a second touch operation should be fine (we just care
  # that all of the records get touched with consistent server-side
  # timestamps).
  def touch_server_side_timestamp
    collection.update_one({ :_id => self.id }, {
      "$currentDate" => {
        "ts" => { "$type" => "timestamp" },
      },
    })
  end
end
