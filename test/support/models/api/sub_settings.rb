class Api::SubSettings
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :http_method, :type => String
  field :regex, :type => String
  embedded_in :api
  embeds_one :settings, :class_name => "Api::Settings"
  accepts_nested_attributes_for :settings
end
