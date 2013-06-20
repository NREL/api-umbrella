object false

extends "admin/stats/_interval_hits"

node :logs do
  @result.results.map do |log|
    log.except(:api_key, :_type, :_score, :_index).merge({
      :email => user_email(log[:user_id])
    })
  end
end

facets = [
  :user_id,
  :request_ip,
  :response_content_type,
  :response_status,
  :request_user_agent_family,
  :request_method,
]

node :pie_facets do
  pie_facets = []

  facets.map do |facet|
    if @result.facets[facet]
      pie_facets << {
        :facet => facet,
        :rows => partial("admin/stats/facet", :object => false, :locals => { :facet => @result.facets[facet] })[:rows],
      }
    end
  end

  pie_facets
end
