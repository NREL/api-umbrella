require "mail_sanitizer"

class ApiUserMailer < ActionMailer::Base
  default :from => "noreply@#{ApiUmbrellaConfig[:web][:default_host]}"

  def signup_email(user, options)
    @user = user

    if(options[:example_api_url].present?)
      @example_api_url = options[:example_api_url].gsub("{{api_key}}", @user.api_key)
      @formatted_example_api_url = options[:example_api_url].gsub("api_key={{api_key}}", "<strong>api_key=#{@user.api_key}</strong>")
    end

    @contact_url = options[:contact_url].presence || "http://#{ApiUmbrellaConfig[:web][:default_host]}/contact/"
    site_name = options[:site_name].presence || ApiUmbrellaConfig[:site_name]

    from = options[:email_from_address].presence || "noreply@#{ApiUmbrellaConfig[:web][:default_host]}"
    if(options[:email_from_name].present?)
      from = "#{options[:email_from_name]} <#{from}>"
    end

    mail :subject => "Your #{site_name} API key",
      :from => MailSanitizer.sanitize_address(from),
      :to => MailSanitizer.sanitize_address(user.email)
  end

  def notify_api_admin(user)
    @user = user

    to = ApiUmbrellaConfig[:web][:admin_notify_email].presence || ApiUmbrellaConfig[:web][:contact_form_email]

    full_name = "#{@user.first_name} #{@user.last_name}"
    from = "noreply@#{ApiUmbrellaConfig[:web][:default_host]}"
    mail :subject => "#{full_name} just subscribed",
         :from => MailSanitizer.sanitize_address(from),
         :to => MailSanitizer.sanitize_address(to)
  end
end
