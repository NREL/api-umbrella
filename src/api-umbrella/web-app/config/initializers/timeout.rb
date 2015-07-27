if(Rails.env.development?)
  Rack::Timeout.timeout = 60 # seconds
else
  Rack::Timeout.timeout = 15 # seconds
end
