object false

extends "admin/stats/_interval_hits"

node :users do
  @result.facets[:user_id][:terms].map do |term|
    {
      :id => term[:term],
      :email => user_email(term[:term]),
      :hits => term[:count],
    }
  end
end
