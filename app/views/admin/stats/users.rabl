object false

extends "admin/stats/_interval_hits"

node :users do
  @result.facets[:user_email][:terms].map do |term|
    {
      :id => term[:term],
      :email => term[:term],
      :hits => term[:count],
    }
  end
end
