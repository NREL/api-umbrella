require "spec_helper"

describe ApiUserMailer do
  describe "signup_email" do
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

  describe "signup_email" do
    before(:each) do
      ApiUmbrellaConfig[:web][:contact_form_email] = "aaa@bbb.com"
      ApiUmbrellaConfig[:web][:default_host] = "localhost.com"
    end

    let(:api_user) do
      FactoryGirl.create(
          :api_user,
          :first_name => "aaa",
          :last_name => "bbb",
          :use_description => "I WANNA DO EVERYTHING",
          :email => "foo@example.com")
    end

    subject { ApiUserMailer.notify_api_admin(api_user).deliver }

    it "send an email " do
      expect { subject }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "send an email to the contact email" do
      subject
      expect(ActionMailer::Base.deliveries.first.to).to eq ["aaa@bbb.com"]
    end

    it "the receiver can be overwrited by the admin " do
      ApiUmbrellaConfig[:web][:admin_notify_email] = "ccc@ddd.com"
      subject
      expect(ActionMailer::Base.deliveries.first.to).to eq ["ccc@ddd.com"]
    end

    it "send an email with the name of the person in the subject" do
      subject
      expect(ActionMailer::Base.deliveries.first.subject).to eq "aaa bbb just subscribed"
    end

    it "send an email from the server name" do
      subject
      expect(ActionMailer::Base.deliveries.first.from).to eq ["noreply@localhost.com"]
    end

    it "send an email with usage in the body" do
      subject
      expect(ActionMailer::Base.deliveries.first.encoded).to include "I WANNA DO EVERYTHING"
    end
  end
end
