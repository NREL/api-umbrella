class Api::Settings
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :append_query_string, :type => String
  field :http_basic_auth, :type => String
  field :require_https, :type => Boolean
  field :disable_api_key, :type => Boolean
  field :required_roles, :type => Array
  field :rate_limit_mode, :type => String
  field :error_templates, :type => Hash
  field :error_data, :type => Hash

  # Relations
  embeds_many :headers, :class_name => "Api::Header"
  embeds_many :rate_limits, :class_name => "Api::RateLimit"
  embedded_in :api
  embedded_in :sub_settings
  embedded_in :api_user

  # Validations
  validates :rate_limit_mode,
    :inclusion => { :in => %w(unlimited custom), :allow_blank => true }
  validate :validate_error_data_yaml_strings

  # Nested attributes
  accepts_nested_attributes_for :headers, :rate_limits, :allow_destroy => true

  # Mass assignment security
  attr_accessible :append_query_string,
    :http_basic_auth,
    :require_https,
    :disable_api_key,
    :rate_limit_mode,
    :required_roles,
    :required_roles_string,
    :error_templates,
    :error_data_yaml_strings,
    :headers_string,
    :rate_limits_attributes,
    :as => [:default, :admin]

  def required_roles_string
    unless @required_roles_string
      @required_roles_string = ""
      if self.required_roles.present?
        @required_roles_string = self.required_roles.join(",")
      end
    end

    @required_roles_string
  end

  def required_roles_string=(string)
    @required_roles_string = string

    roles = nil
    if(string.present?)
      roles = string.split(",").map { |role| role.strip }
    end

    self.required_roles = roles
  end

  def headers_string
    unless @headers_string
      @headers_string = ""
      if(self.headers.present?)
        @headers_string = self.headers.map do |header|
          header.to_s
        end.join("\n")
      end
    end

    @headers_string
  end

  def headers_string=(string)
    @headers_string = string

    header_objects = []

    header_lines = string.split(/[\r\n]+/)
    header_lines.each do |line|
      next if(line.strip.blank?)

      parts = line.split(":", 2)
      header_objects << Api::Header.new({
        :key => parts[0].to_s.strip,
        :value => parts[1].to_s.strip,
      })
    end

    self.headers = header_objects
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
          @error_data_yaml_strings[key] = Psych.dump(value).gsub(/^---\s*\n/, "").strip
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

  private

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
end
