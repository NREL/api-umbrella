module Admin::StatsHelper
  def aggregation_result(aggregation_name)
    name = aggregation_name.to_s.pluralize

    buckets = []
    top_buckets = @result.aggregations["top_#{name}"]["buckets"]
    with_value_count = @result.aggregations["value_count_#{name}"]["value"]
    missing_count = @result.aggregations["missing_#{name}"]["doc_count"]

    other_hits = with_value_count
    top_buckets.each do |bucket|
      other_hits -= bucket["doc_count"]

      buckets << {
        "key" => bucket["key"],
        "count" => bucket["doc_count"],
      }
    end

    if(missing_count > 0)
      if(buckets.length < 10 || missing_count >= buckets.last["count"])
        buckets << {
          "key" => "Missing / Unknown",
          "count" => missing_count,
        }
      end
    end

    total = with_value_count.to_f + missing_count
    buckets.each do |bucket|
      bucket["percent"] = ((bucket["count"] / total) * 100).round
    end

    if(other_hits > 0)
      buckets << {
        "key" => "Other",
        "count" => other_hits,
      }
    end

    buckets
  end

  def facet_result(facet_name)
    facet = @result.facets[facet_name.to_s]

    terms = facet["terms"]

    if(facet["missing"] > 0)
      if(terms.length < 10 || facet["missing"] >= terms.last["count"])
        terms << {
          "term" => "Missing / Unknown",
          "count" => facet["missing"],
        }
      end
    end

    if(facet["other"] > 0)
      terms << {
        "term" => "Other",
        "count" => facet["other"],
      }
    end

    total = @result.total.to_f
    terms.each do |term|
      term["percent"] = ((term["count"] / total) * 100).round
    end

    terms
  end

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

  def region_location_columns(term)
    columns = []

    if(@search.query[:facets][:regions][:terms][:field] == "request_ip_city")
      city = term["term"]
      location = @result.cities[city]

      lat = nil
      lon = nil
      if location
        lat = location["lat"].to_f
        lon = location["lon"].to_f
      end

      columns += [
        { :v => lat },
        { :v => lon },
        { :v => city },
      ]
    else
      columns << { :v => term["term"], :f => region_name(term["term"]) }
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
