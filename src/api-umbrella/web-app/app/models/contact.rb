class Contact
  include ActiveModel::Model

  attr_accessor :name, :email, :api, :subject, :message

  validates :name,
    :presence => { :message => "Provide your first name." }
  validates :email,
    :presence => { :message => "Provide your email address." },
    :format => {
      :with => /.+@.+\..+/,
      :allow_blank => true,
      :message => "Provide a valid email address.",
    }
  validates :api,
    :presence => { :message => "Provide the API." }
  validates :subject,
    :presence => { :message => "Provide a subject." }
  validates :message,
    :presence => { :message => "Provide a message." }

  def deliver
    if self.valid?
      ContactMailer.contact_email(self).deliver_later
    else
      false
    end
  end
end
