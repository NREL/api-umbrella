require "spec_helper"

describe "/api/v1/users" do
  # Make sure our API key creation endpoint can be successfully called with
  # IE8-9's shimmed pseudo-CORS support. This ensures API keys can be created
  # even if the endpoint is called with empty or text/plain content-types. See
  # ApplicationController#parse_post_for_pseudo_ie_cors for more detail.
  describe "IE8-9 pseudo-CORS compatibility" do
    let(:url) { "/api/v1/users.json?api_key=DEMO_KEY" }
    let(:headers) do
      {
        "HTTP_X_API_ROLES" => "api-umbrella-key-creator",
      }
    end

    let(:post_data) do
      {
        :user => {
          :first_name => "Mr",
          :last_name => "Potato",
          :email => "potato@example.com",
          :use_description => "",
          :terms_and_conditions => "1",
        },
      }
    end

    it "accepts form data with a nil content-type" do
      expect do
        post url, post_data, headers.merge("CONTENT_TYPE" => nil)

        response.status.should eql(201)
        data = MultiJson.load(response.body)
        data["user"]["last_name"].should eql("Potato")

        user = ApiUser.find(data["user"]["id"])
        user.last_name.should eql("Potato")
      end.to change { ApiUser.count }.by(1)
    end

    it "accepts form data with a empty content-type" do
      expect do
        post url, post_data, headers.merge("CONTENT_TYPE" => "")

        response.status.should eql(201)
        data = MultiJson.load(response.body)
        data["user"]["last_name"].should eql("Potato")

        user = ApiUser.find(data["user"]["id"])
        user.last_name.should eql("Potato")
      end.to change { ApiUser.count }.by(1)
    end

    it "accepts form data a content-type of text/plain" do
      expect do
        post url, post_data, headers.merge("CONTENT_TYPE" => "text/plain")

        response.status.should eql(201)
        data = MultiJson.load(response.body)
        data["user"]["last_name"].should eql("Potato")

        user = ApiUser.find(data["user"]["id"])
        user.last_name.should eql("Potato")
      end.to change { ApiUser.count }.by(1)
    end
  end
end
