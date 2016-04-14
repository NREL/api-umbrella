require "spec_helper"

describe ContactMailer do
  describe "OSVDB-131677 security" do
    before(:each) do
      ApiUmbrellaConfig[:web][:contact_form_email] = "test@example.com"
      @contact = Contact.new({
        :name => "John Doe",
        :api => "Foo",
        :subject => "Bar",
        :message => "Hello, World",
      })
    end

    it "accepts addresses without newlines" do
      expect do
        @contact.email = "foo@example.com"
        ContactMailer.contact_email(@contact).deliver
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "rejects addresses with newlines" do
      expect do
        expect do
          @contact.email = "foo@example.com\nfoo"
          ContactMailer.contact_email(@contact).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "rejects addresses with carriage returns" do
      expect do
        expect do
          @contact.email = "foo@example.com\rfoo"
          ContactMailer.contact_email(@contact).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "accepts addresses 500 chars or less" do
      expect do
        @contact.email = "#{"o" * 488}@example.com"
        ContactMailer.contact_email(@contact).deliver
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "rejects addresses greater than 500 chars" do
      expect do
        expect do
          @contact.email = "#{"o" * 489}@example.com"
          ContactMailer.contact_email(@contact).deliver
        end.to raise_error(MailSanitizer::InvalidAddress)
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end
  end
end
