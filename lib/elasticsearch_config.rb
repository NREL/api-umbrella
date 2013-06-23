class ElasticsearchConfig < Settingslogic
  source "#{Rails.root}/config/elasticsearch.yml"
  namespace Rails.env
end
