class Api::Settings
  include Mongoid::Document

  # Fields
  field :append_query_string, :type => String
  field :http_basic_auth, :type => String
  field :require_https, :type => Boolean
  field :disable_api_key, :type => Boolean
  field :required_roles, :type => Array
  field :hourly_rate_limit, :type => Integer

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
    :hourly_rate_limit

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
end
