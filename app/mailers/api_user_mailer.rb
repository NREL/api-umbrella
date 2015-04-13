class ApiUserMailer < ActionMailer::Base
  default :from => "noreply@#{ApiUmbrellaConfig[:default_host]}"

  def signup_email(user, options)
    @user = user

    if(options[:example_api_url].present?)
      @example_api_url = options[:example_api_url].gsub("{{api_key}}", @user.api_key)
      @formatted_example_api_url = options[:example_api_url].gsub("api_key={{api_key}}", "<strong>api_key=#{@user.api_key}</strong>")
    end

    @contact_url = options[:contact_url].presence || "http://#{ApiUmbrellaConfig[:default_host]}/contact/"
    from = options[:email_from].presence || "noreply@#{ApiUmbrellaConfig[:default_host]}"
    site_name = options[:site_name].presence || ApiUmbrellaConfig[:site_name]

    mail :subject => "Your #{site_name} API key",
      :from => from,
      :to => user.email
  end
end
