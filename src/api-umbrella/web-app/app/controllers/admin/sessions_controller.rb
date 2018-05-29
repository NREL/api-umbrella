class Admin::SessionsController < Devise::SessionsController
  before_action :first_time_setup_check
  before_action :only_for_local_auth, :only => [:create]
  skip_after_action :verify_authorized

  # Allow the logout endpoint to be hit via ajax from the Ember app, where the
  # request has the admin auth token, but not the default csrf token.
  prepend_before_action :authenticate_admin_from_token!, :only => [:destroy]
  skip_before_action :verify_authenticity_token, :only => [:destroy]
  before_action :verify_authenticity_token_with_admin_token, :only => [:destroy]

  def auth
    response = {
      "authenticated" => !current_admin.nil?,
    }

    if current_admin
      response.merge!({
        "analytics_timezone" => ApiUmbrellaConfig[:analytics][:timezone],
        "username_is_email" => ApiUmbrellaConfig[:web][:admin][:username_is_email],
        "local_auth_enabled" => ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_enabled][:local],
        "password_length_min" => ApiUmbrellaConfig[:web][:admin][:password_length_min],
        "api_umbrella_version" => API_UMBRELLA_VERSION,
        "admin" => current_admin.as_json.slice(
          "email",
          "id",
          "superuser",
          "username",
        ).merge({
          "permissions" => {
            "analytics" => current_admin.can?("analytics"),
            "user_view" => current_admin.can?("user_view"),
            "user_manage" => current_admin.can?("user_manage"),
            "admin_manage" => current_admin.can?("admin_manage"),
            "backend_manage" => current_admin.can?("backend_manage"),
            "backend_publish" => current_admin.can?("backend_publish"),
          },
        }),
        "api_key" => ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").order_by(:created_at.asc).first.api_key,
        "admin_auth_token" => current_admin.authentication_token,
      })
    end

    respond_to do|format|
      format.json { render(:json => response) }
    end
  end

  private

  def set_flash_message(key, kind, options = {})
    # Don't set the "signed in" flash message, since we redirect to the Ember
    # app after signing in, where flashes won't be displayed (so displaying the
    # "signed in" message the next time they get back to the Rails login page
    # is confusing).
    if(kind != :signed_in)
      super(key, kind, options)
    end
  end

  def first_time_setup_check
    if(Admin.needs_first_account?)
      redirect_to new_admin_registration_path
    end
  end

  def only_for_local_auth
    unless(ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_enabled][:local])
      raise ActionController::RoutingError.new("Not Found")
    end
  end
end
