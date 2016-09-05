require "common_validations"

class Api::UrlMatch
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :frontend_prefix, :type => String
  field :backend_prefix, :type => String

  # Relations
  embedded_in :api

  # Validations
  validates :frontend_prefix,
    :presence => true,
    :format => {
      :with => CommonValidations::URL_PREFIX_FORMAT,
      :message => :invalid_url_prefix_format,
    }
  validates :backend_prefix,
    :presence => true,
    :format => {
      :with => CommonValidations::URL_PREFIX_FORMAT,
      :message => :invalid_url_prefix_format,
    }
end
