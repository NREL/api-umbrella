require "common_validations"

class Api::UrlMatch
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
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

  # Mass assignment security
  attr_accessible :frontend_prefix,
    :backend_prefix,
    :as => [:default, :admin]
end
