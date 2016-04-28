class ApplicationController < ActionController::Base
  include Pundit
  include DatatablesHelper
  protect_from_forgery

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
        time = Time.parse(time)
      when Numeric
        time = Time.at(time / 1000.0)
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

  def set_analytics_adapter
    if(params[:beta_analytics] == "true")
      @analytics_adapter = "kylin"
    else
      @analytics_adapter = ApiUmbrellaConfig[:analytics][:adapter]
    end
  end

  def set_time_zone
    old_time_zone = Time.zone
    Time.zone = ApiUmbrellaConfig[:analytics][:timezone]
    yield
  ensure
    Time.zone = old_time_zone
  end
end
