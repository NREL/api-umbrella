class AdminMailer < ActionMailer::Base
  default :from => "noreply@#{ApiUmbrellaConfig[:web][:default_host]}"

  def invite(admin_id, token)
    @admin = Admin.find(admin_id)
    @token = token

    @site_name = ApiUmbrellaConfig[:site_name]
    from = "noreply@#{ApiUmbrellaConfig[:web][:default_host]}"

    mail :subject => "#{@site_name} Admin Access",
      :from => from,
      :to => @admin.email
  end
end
