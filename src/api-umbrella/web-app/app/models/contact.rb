class Contact
  include ActiveAttr::Model

  attribute :name, :type => String
  attribute :email, :type => String
  attribute :api, :type => String
  attribute :subject, :type => String
  attribute :message, :type => String

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
      ContactMailer.contact_email(self.as_json).deliver_later
    else
      false
    end
  end
end
