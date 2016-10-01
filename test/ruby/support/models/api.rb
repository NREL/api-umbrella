class Api
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String
  field :sort_order, :type => Integer
  field :backend_protocol, :type => String
  field :frontend_host, :type => String
  field :backend_host, :type => String
  field :balance_algorithm, :type => String
  field :created_by, :type => String
  field :updated_by, :type => String
  embeds_one :settings, :class_name => "Api::Settings"
  embeds_many :servers, :class_name => "Api::Server"
  embeds_many :url_matches, :class_name => "Api::UrlMatch"
  embeds_many :sub_settings, :class_name => "Api::SubSettings"
  embeds_many :rewrites, :class_name => "Api::Rewrite"
end

