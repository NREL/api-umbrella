class ContactMailer < ActionMailer::Base
  default :from => "noreply@#{ConfigSettings.default_host}"

  def contact_email(contact)
    @contact = contact

    mail :from => contact.email,
      :subject => "#{t("site_name")} Contact Message from #{contact.email}",
      :to => "nick.muerdter@nrel.gov"
  end
end
