require 'spec_helper'

describe ApiUser do
  context "api key generation" do
    before(:all) do
      @api_user = FactoryGirl.create(:api_user, :api_key => nil)
    end

    it "generates a new key on create" do
      @api_user.api_key.should_not eq(nil)
    end

    it "contains only A-Z, a-z, and 0-9 chars" do
      @api_user.api_key.should match(/^[0-9A-Za-z]+$/)
    end

    it "is 40 characters long" do
      @api_user.api_key.length.should eq(40)
    end
  end
end
