class ApiBackendSettings < ApplicationRecord
  belongs_to :api_backend
  has_many :http_headers, -> { order(:sort_order) }, :class_name => "ApiBackendHttpHeader"
  has_many :rate_limits, -> { order(:duration, :limit_by, :limit_to) }
  has_and_belongs_to_many :required_roles, -> { order(:id) }, :class_name => "ApiRole", :join_table => "api_backend_settings_required_roles"

  def required_roles
    self.required_role_ids
  end

  def required_roles=(ids)
    ApiRole.insert_missing(ids)
    self.required_role_ids = ids
  end

  def headers
    get_http_headers("request")
  end

  def headers=(values)
    set_http_headers("request", values)
  end

  def default_response_headers
    get_http_headers("response_default")
  end

  def default_response_headers=(values)
    set_http_headers("response_default", values)
  end

  def override_response_headers
    get_http_headers("response_override")
  end

  def override_response_headers=(values)
    set_http_headers("response_override", values)
  end

  private

  def get_http_headers(header_type)
    self.http_headers.select { |h| h.header_type == header_type }
  end

  def set_http_headers(header_type, values)
    headers = self.http_headers.reject { |h| h.header_type == header_type }
    values.each_with_index do |v, i|
      v.header_type = header_type
      v.sort_order = i
    end
    self.http_headers = headers + values
  end
end
