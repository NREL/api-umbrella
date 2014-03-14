class ApiUserMailer < ActionMailer::Base
  default :from => "from@example.com"

  def signup_email(user)
    @user = user

    mail :from => "noreply@api.data.gov",
      :subject => "Your #{t("site_name")} API key",
      :to => user.email
  end
end
