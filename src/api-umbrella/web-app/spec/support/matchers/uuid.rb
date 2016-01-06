RSpec::Matchers.define :be_a_uuid do
  match do |actual|
    actual =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
  end
end
