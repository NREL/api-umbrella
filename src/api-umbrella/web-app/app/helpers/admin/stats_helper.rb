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

    if(other_hits && other_hits > 0)
      buckets << {
        "key" => "Other",
        "count" => other_hits,
      }
    end

    buckets
  end

  def region_location_columns(bucket)
    columns = []

    if(@search.query[:aggregations][:regions][:terms][:field] == "request_ip_city")
      city = bucket["key"]
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
      columns << { :v => bucket["key"], :f => region_name(bucket["key"]) }
    end

    columns
  end

  def region_id(id)
    if(params[:region] == "US")
      id = "US-#{id}"
    end

    id
  end

  def region_name(code)
    name = code
    case(params[:region])
    when "world"
      country = ISO3166::Country.new(code)
      if country
        name = country.name
      end
    when /^[A-Z]{2}$/
      country = ISO3166::Country.new(params[:region])
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
