class ApiBackend < ApplicationRecord
  has_one :settings, :class_name => "ApiBackendSettings"
  has_many :servers, :class_name => "ApiBackendServer"
  has_many :url_matches, :class_name => "ApiBackendUrlMatch"
  has_many :sub_settings, :class_name => "ApiBackendSubUrlSettings"
  has_many :rewrites, :class_name => "ApiBackendRewrite"

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
    settings_options = {
      :methods => [
        :headers,
        :default_response_headers,
        :override_response_headers,
      ],
      :include => {
        :http_headers => {},
        :rate_limits => {},
      },
    }
    options ||= {}
    options.merge!({
      :include => {
        :settings => settings_options,
        :servers => {},
        :url_matches => {},
        :sub_settings => {
          :include => {
            :settings => settings_options,
          },
        },
        :rewrites => {},
      },
    })
    super(options)
  end
end
