class Contact
  include ActiveModel::Conversion
  include ActiveModel::MassAssignmentSecurity
  include ActiveModel::Validations

  attr_accessor :name, :email, :message

  attr_accessible :name, :email, :message

  validates :name,
    :presence => { :message => "Provide your first name." }
  validates :email,
    :presence => { :message => "Provide your email address." },
    :format => {
      :with => /.+@.+\..+/,
      :allow_blank => true,
      :message => "Provide a valid email address.",
    }
  validates :message,
    :presence => { :message => "Provide a message." }

  def initialize(attrs = {})
    self.attributes = attrs
  end

  def attributes=(values)
    sanitize_for_mass_assignment(values).each do |k, v|
      __send__("#{k}=", v)
    end
  end

  def deliver
    if self.valid?
      ContactMailer.delay(:queue => "mailers").contact_email(self)
    else
      false
    end
  end

  def persisted?
    false
  end
end
