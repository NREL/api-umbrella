class ApiUserMailer < ActionMailer::Base
  default :from => "noreply@#{ConfigSettings.default_host}"

  def signup_email(user)
    @user = user

    mail :subject => "Your #{t("site_name")} API key",
      :to => user.email
  end
end
