require "mail_sanitizer"

class ContactMailer < ActionMailer::Base
  default :from => "noreply@#{ApiUmbrellaConfig[:default_host]}"

  def contact_email(contact)
    @contact = contact

    mail :reply_to => MailSanitizer.sanitize_address(contact.email),
      :subject => "#{ApiUmbrellaConfig[:site_name]} Contact Message from #{contact.email}",
      :to => MailSanitizer.sanitize_address(ApiUmbrellaConfig[:web][:contact_form_email])
  end
end
