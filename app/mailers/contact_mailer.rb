class ContactMailer < ActionMailer::Base
  default :from => "from@example.com"

  def contact_email(contact)
    @contact = contact

    mail :from => contact.email,
      :subject => "#{t("site_name")} Contact Message from #{contact.email}",
      :to => "nick.muerdter@nrel.gov"
  end
end
