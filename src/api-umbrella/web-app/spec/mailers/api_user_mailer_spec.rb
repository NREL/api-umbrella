require "spec_helper"

describe ApiUserMailer do
  describe "OSVDB-131677 security" do
    it "accepts recipients without newlines" do
      expect do
        api_user = FactoryGirl.create(:api_user, :email => "foo@example.com")
        ApiUserMailer.signup_email(api_user, {}).deliver
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "rejects recipients with newlines" do
      expect do
        expect do
          api_user = FactoryGirl.create(:api_user, :email => "foo@example.com\nfoo")
          ApiUserMailer.signup_email(api_user, {}).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "rejects recipients with carriage returns" do
      expect do
        expect do
          api_user = FactoryGirl.create(:api_user, :email => "foo@example.com\rfoo")
          ApiUserMailer.signup_email(api_user, {}).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "accepts recipients 500 chars or less" do
      expect do
        api_user = FactoryGirl.create(:api_user, :email => "#{"o" * 488}@example.com")
        ApiUserMailer.signup_email(api_user, {}).deliver
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "rejects recipients greater than 500 chars" do
      expect do
        expect do
          api_user = FactoryGirl.create(:api_user, :email => "#{"o" * 489}@example.com")
          ApiUserMailer.signup_email(api_user, {}).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "accepts from addresses without newlines" do
      expect do
        api_user = FactoryGirl.create(:api_user)
        ApiUserMailer.signup_email(api_user, { :email_from_address => "foo@example.com" }).deliver
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "rejects from addresses with newlines" do
      expect do
        expect do
          api_user = FactoryGirl.create(:api_user)
          ApiUserMailer.signup_email(api_user, { :email_from_address => "foo@example.com\nfoo" }).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "rejects from addresses with carriage returns" do
      expect do
        expect do
          api_user = FactoryGirl.create(:api_user)
          ApiUserMailer.signup_email(api_user, { :email_from_address => "foo@example.com\rfoo" }).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "accepts from addresses 500 chars or less" do
      expect do
        api_user = FactoryGirl.create(:api_user)
        ApiUserMailer.signup_email(api_user, { :email_from_address => "#{"o" * 488}@example.com" }).deliver
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "rejects from addresses greater than 500 chars" do
      expect do
        expect do
          api_user = FactoryGirl.create(:api_user)
          ApiUserMailer.signup_email(api_user, { :email_from_address => "#{"o" * 489}@example.com" }).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

  end
end
