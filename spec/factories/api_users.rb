FactoryGirl.define do
  factory :api_user do
    first_name "Ambrose"
    last_name "Burnside"
    sequence(:email) { |n| "ambrose.burnside#{n}@example.com" }
    if(ApiUser.fields.include?("website"))
      website "http://example.com/"
    end
    terms_and_conditions "1"

    factory :invalid_api_user do
      terms_and_conditions ""
    end

    factory :xss_api_user do
      email 'a@"><script class="xss-test">alert("Hello first_name");</script>.com'
      first_name '"><script class="xss-test">alert("Hello first_name");</script>'
      last_name '"><script class="xss-test">alert("Hello last_name");</script>'
      use_description '"><script class="xss-test">alert("Hello use_description");</script>'
      registration_source '"><script class="xss-test">alert("Hello registration_source");</script>'
    end
  end
end
