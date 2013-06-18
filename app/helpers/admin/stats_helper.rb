module Admin::StatsHelper
  def formatted_interval_time(time)
    time = Time.at(time / 1000).in_time_zone

    case params[:interval]
    when "minute"
      time.strftime("%a, %b %-d, %Y %-I:%0M%P %Z")
    when "hour"
      time.strftime("%a, %b %-d, %Y %-I:%0M%P %Z")
    when "day"
      time.strftime("%a, %b %-d, %Y")
    when "week"
      end_of_week = time.end_of_week
      if(end_of_week > @end_time)
        end_of_week = @end_time
      end

      "#{time.strftime("%b %-d, %Y")} - #{end_of_week.strftime("%b %-d, %Y")}"
    when "month"
      end_of_month = time.end_of_month
      if(end_of_month > @end_time)
        end_of_month = @end_time
      end

      "#{time.strftime("%b %-d, %Y")} - #{end_of_month.strftime("%b %-d, %Y")}"
    end
  end

  def region_location_columns(term)
    columns = []

    if(@query[:facets][:regions][:terms][:field] == "request_ip_city")
      city = term[:term]
      location = @cities[city]

      lat = nil
      lon = nil
      if location
        lat = location[:lat].to_f
        lon = location[:lon].to_f
      end

      columns += [
        { :v => lat },
        { :v => lon },
        { :v => city },
      ]
    else
      columns << { :v => term[:term], :f => region_name(term[:term]) }
    end

    columns
  end

  def region_name(code)
    name = code
    case(params[:region])
    when "world"
      country = Country[code]
      if country
        name = country.name
      end
    when /^[A-Z]{2}$/
      country = Country[params[:region]]
      if country
        state = country.states[code]
        if(state)
          name = state["name"]
        end
      end
    end

    name
  end
end
