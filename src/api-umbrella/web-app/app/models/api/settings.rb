class Api::Settings
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :append_query_string, :type => String
  field :http_basic_auth, :type => String
  field :require_https, :type => String
  field :require_https_transition_start_at, :type => Time
  field :disable_api_key, :type => Boolean
  field :api_key_verification_level, :type => String
  field :api_key_verification_transition_start_at, :type => Time
  field :required_roles, :type => Array
  field :required_roles_override, :type => Boolean
  field :allowed_ips, :type => Array
  field :allowed_referers, :type => Array
  field :rate_limit_mode, :type => String
  field :anonymous_rate_limit_behavior, :type => String
  field :authenticated_rate_limit_behavior, :type => String
  field :pass_api_key_header, :type => Boolean
  field :pass_api_key_query_param, :type => Boolean
  field :error_templates, :type => Hash
  field :error_data, :type => Hash

  # Relations
  embeds_many :headers, :class_name => "Api::Header"
  embeds_many :rate_limits, :class_name => "Api::RateLimit"
  embeds_many :default_response_headers, :class_name => "Api::Header"
  embeds_many :override_response_headers, :class_name => "Api::Header"
  embedded_in :api
  embedded_in :sub_settings
  embedded_in :api_user

  # Validations
  validates :require_https,
    :inclusion => { :in => %w(required_return_error transition_return_error optional), :allow_blank => true }
  validates :api_key_verification_level,
    :inclusion => { :in => %w(none transition_email required_email), :allow_blank => true }
  validates :rate_limit_mode,
    :inclusion => { :in => %w(unlimited custom), :allow_blank => true }
  validates :anonymous_rate_limit_behavior,
    :inclusion => { :in => %w(ip_fallback ip_only), :allow_blank => true }
  validates :authenticated_rate_limit_behavior,
    :inclusion => { :in => %w(all api_key_only), :allow_blank => true }
  validate :validate_error_data_yaml_strings
  validate :validate_error_data

  # Nested attributes
  accepts_nested_attributes_for :headers, :rate_limits, :default_response_headers, :override_response_headers, :allow_destroy => true

  def headers_string
    read_headers_string(:headers)
  end

  def headers_string=(string)
    write_headers_string(:headers, string)
  end

  def default_response_headers_string
    read_headers_string(:default_response_headers)
  end

  def default_response_headers_string=(string)
    write_headers_string(:default_response_headers, string)
  end

  def override_response_headers_string
    read_headers_string(:override_response_headers)
  end

  def override_response_headers_string=(string)
    write_headers_string(:override_response_headers, string)
  end

  def error_templates=(templates)
    templates ||= {}
    templates.reject! { |key, value| value.blank? }
    self[:error_templates] = templates
  end

  def error_data_yaml_strings
    unless @error_data_yaml_strings
      @error_data_yaml_strings = {}
      if self.error_data.present?
        self.error_data.each do |key, value|
          @error_data_yaml_strings[key] = Psych.dump(value).gsub(/\A---.*?\n/, "").strip
        end
      end
    end

    @error_data_yaml_strings
  end

  def error_data_yaml_strings=(strings)
    @error_data_yaml_strings = strings

    begin
      data = {}
      if(strings.present?)
        strings.each do |key, value|
          if value.present?
            data[key] = SafeYAML.load(value)
          end
        end
      end

      self.error_data = data
    rescue Psych::SyntaxError => error
      # Ignore YAML errors, we'll deal with validating during
      # validate_error_data_yaml_strings.
      logger.info("YAML parsing error: #{error.message}")
    end
  end

  def set_transition_starts_on_publish
    if(self.require_https =~ /^transition_/)
      if(self.require_https_transition_start_at.blank?)
        self.require_https_transition_start_at = Time.now.utc
      end
    else
      if(self.require_https_transition_start_at.present?)
        self.require_https_transition_start_at = nil
      end
    end

    if(self.api_key_verification_level =~ /^transition_/)
      if(self.api_key_verification_transition_start_at.blank?)
        self.api_key_verification_transition_start_at = Time.now.utc
      end
    else
      if(self.api_key_verification_transition_start_at.present?)
        self.api_key_verification_transition_start_at = nil
      end
    end
  end

  def serializable_hash(options = nil)
    hash = super(options)
    # Ensure all embedded relationships are at least null in the JSON output
    # (rather than not being present), or else Ember-Data's serialization
    # throws warnings.
    hash["default_response_headers"] ||= nil
    hash["headers"] ||= nil
    hash["override_response_headers"] ||= nil
    hash["rate_limits"] ||= nil
    hash
  end

  private

  def read_headers_string(field)
    @headers_strings ||= {}
    field = field.to_sym

    unless @headers_strings[field]
      @headers_strings[field] = ""
      current_value = self.send(field)
      if(current_value.present?)
        @headers_strings[field] = current_value.map do |header|
          header.to_s
        end.join("\n")
      end
    end

    @headers_strings[field]
  end

  def write_headers_string(field, string)
    header_objects = []

    if(string.present?)
      header_lines = string.split(/[\r\n]+/)
      header_lines.each do |line|
        next if(line.strip.blank?)

        parts = line.split(":", 2)
        header_objects << Api::Header.new({
          :key => parts[0].to_s.strip,
          :value => parts[1].to_s.strip,
        })
      end
    end

    self.send(:"#{field}=", header_objects)
    @headers_strings.delete(field.to_sym) if(@headers_strings)
  end

  def validate_error_data_yaml_strings
    strings = @error_data_yaml_strings
    if(strings.present?)
      strings.each do |key, value|
        if value.present?
          begin
            SafeYAML.load(value)
          rescue Psych::SyntaxError => error
            self.errors.add("error_data_yaml_strings.#{key}", "YAML parsing error: #{error.message}")
          end
        end
      end
    end
  end

  def validate_error_data
    if(self.error_data.present?)
      unless(self.error_data.kind_of?(Hash))
        self.errors.add("error_data", "unexpected type (must be a hash)")
        return false
      end

      self.error_data.each do |key, value|
        unless(value.kind_of?(Hash))
          self.errors.add("error_data.#{key}", "unexpected type (must be a hash)")
        end
      end
    end
  end
end
