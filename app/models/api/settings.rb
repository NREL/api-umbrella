class Api::Settings
  include Mongoid::Document

  # Fields
  field :append_query_string, :type => String
  field :http_basic_auth, :type => String
  field :require_https, :type => Boolean
  field :disable_api_key, :type => Boolean
  field :required_roles, :type => Array
  field :hourly_rate_limit, :type => Integer
  field :error_templates, :type => Hash
  field :error_data, :type => Hash

  # Relations
  embeds_many :headers, :class_name => "Api::Header"
  embedded_in :api
  embedded_in :sub_settings

  # Mass assignment security
  attr_accessible :_id,
    :append_query_string,
    :http_basic_auth,
    :require_https,
    :disable_api_key,
    :required_roles,
    :required_roles_string,
    :hourly_rate_limit,
    :error_templates,
    :error_data_yaml_strings

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

  def error_templates=(templates)
    if(templates.present?)
      templates.reject! { |key, value| value.blank? }
      self[:error_templates] = templates
    end
  end

  def error_data_yaml_strings
    unless @error_data_yaml_strings
      @error_data_yaml_strings = {}
      if self.error_data.present?
        self.error_data.each do |key, value|
          @error_data_yaml_strings[key] = YAML.dump(value).gsub(/^---\n/, "").strip
        end
      end
    end

    @error_data_yaml_strings
  end

  def error_data_yaml_strings=(strings)
    @error_data_yaml_strings = strings

    data = {}
    if(strings.present?)
      strings.each do |key, value|
        if value.present?
          data[key] = YAML.load(value)
        end
      end
    end

    self.error_data = data
  end
end
