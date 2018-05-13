class ApplicationController < ActionController::Base
  include Pundit
  include DatatablesHelper
  prepend_around_filter :use_locale
  protect_from_forgery :with => :exception

  before_action :set_cache_control
  around_action :set_userstamp

  def after_sign_in_path_for(resource)
    if(resource.is_a?(Admin))
      "/admin/#/login"
    else
      super
    end
  end

  def pundit_user
    current_admin
  end

  helper_method :formatted_interval_time
  def formatted_interval_time(time)
    time = Time.at(time / 1000).in_time_zone

    case @search.interval
    when "minute"
      time.strftime("%a, %b %-d, %Y %-I:%0M%P %Z")
    when "hour"
      time.strftime("%a, %b %-d, %Y %-I:%0M%P %Z")
    when "day"
      time.strftime("%a, %b %-d, %Y")
    when "week"
      end_of_week = time.end_of_week
      if(end_of_week > @search.end_time)
        end_of_week = @search.end_time
      end

      "#{time.strftime("%b %-d, %Y")} - #{end_of_week.strftime("%b %-d, %Y")}"
    when "month"
      end_of_month = time.end_of_month
      if(end_of_month > @search.end_time)
        end_of_month = @search.end_time
      end

      "#{time.strftime("%b %-d, %Y")} - #{end_of_month.strftime("%b %-d, %Y")}"
    end
  end

  helper_method :csv_time
  def csv_time(time)
    if(time)
      case(time)
      when String
        time = Time.parse(time).utc
      when Numeric
        time = Time.at(time / 1000.0).utc
      end

      time.utc.strftime("%Y-%m-%d %H:%M:%S")
    end
  end

  # This allows us to support IE8-9 and their shimmed pseudo-CORS support. This
  # parses the post body as form data, even if the content-type is text/plain
  # or unknown.
  #
  # The issue is that IE8-9 will send POST data with an empty Content-Type
  # (see: http://goo.gl/oumNaF). Some Rails servers (Passenger) will treat this
  # as nil, in which case Rack parses the post data as a form data (see:
  # http://goo.gl/jEEtCC). However, other Rails server (Puma) will default
  # an empty Content-Type as "text/plain", in which case Rack will not parse
  # the post data (see: http://goo.gl/y6JsqL).
  #
  # For this latter case of Rack servers, we will force parsing of our post
  # body as form data so IE's form data is present on the rails "params"
  # object. But even aside from these differences in Rack servers, this is
  # probably a good idea, since apparently historically IE8-9 would actually
  # send the data as "text/plain" rather than an empty content-type.
  def parse_post_for_pseudo_ie_cors
    if(request.post? && request.POST.blank? && request.raw_post.present?)
      params.merge!(Rack::Utils.parse_nested_query(request.raw_post))
    end
  end

  def use_locale
    locale = http_accept_language.language_region_compatible_from(I18n.available_locales) || I18n.default_locale
    I18n.with_locale(locale) do
      yield
    end
  end

  def set_analytics_adapter
    @analytics_adapter = ApiUmbrellaConfig[:analytics][:adapter]
  end

  def set_time_zone
    old_time_zone = Time.zone
    Time.zone = ApiUmbrellaConfig[:analytics][:timezone]
    yield
  ensure
    Time.zone = old_time_zone
  end

  def signed_in_root_path(resource_or_scope)
    admin_path
  end

  def after_sign_out_path_for(resource_or_scope)
    admin_path
  end

  private

  def authenticate_admin_from_token!
    admin_token = request.headers['X-Admin-Auth-Token'].presence
    admin = admin_token && Admin.where(:authentication_token => admin_token.to_s).first

    if admin
      # Don't store the user on the session, so the token is required on every
      # request.
      sign_in(admin, :store => false)

      # The normal userstamp before_action that set's the current admin fires
      # before we handle token authentication. To fix that, force the userstamp
      # model to pickup the current admin account after this token-based login.
      unless RequestStore.store[:current_userstamp_user]
        begin
          RequestStore.store[:current_userstamp_user] = current_admin
        rescue => e
          Rails.logger.warn("Unexpected error setting userstamp: #{e}")
        end
      end
    end
  end

  # This can be used to replace the default Rails "verify_authenticity_token"
  # CSRF protection in cases where the endpoint may be hit via ajax by an admin
  # (with the X-Admin-Auth-Token header provided), or via a normal Rails
  # server-side submit (in which case the default CSRF token will be present).
  #
  # If the "X-Admin-Auth-Token" header is being passed in, then we can consider
  # that an effective replacement of the CSRF token value (since only a local
  # application should have knowledge of this token). But if this auth token
  # isn't passed in, then we fallback to the default rails CSRF logic in
  # verify_authenticity_token.
  def verify_authenticity_token_with_admin_token
    admin_token = request.headers['X-Admin-Auth-Token'].presence
    if(!current_admin || !admin_token || admin_token != current_admin.authentication_token)
      verify_authenticity_token
    end
  end

  def set_cache_control
    response.headers["Cache-Control"] = "no-cache, max-age=0, must-revalidate, no-store"
    response.headers["Pragma"] = "no-cache"
  end

  def set_userstamp
    orig = RequestStore.store[:current_userstamp_user]
    RequestStore.store[:current_userstamp_user] = current_admin
    yield
  ensure
    RequestStore.store[:current_userstamp_user] = orig
  end
end
