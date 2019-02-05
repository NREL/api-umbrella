class LogResult::Base
  attr_reader :raw_result

  def initialize(search, raw_result)
    @search = search
    @raw_result = raw_result
  end

  def total
    raw_result["hits"]["total"]
  end

  def documents
    raw_result["hits"]["hits"]
  end

  def aggregations
    raw_result["aggregations"]
  end

  def hits_over_time
    unless @hits_over_time
      @hits_over_time = {}

      if(aggregations && aggregations["hits_over_time"])
        aggregations["hits_over_time"]["buckets"].each do |bucket|
          @hits_over_time[bucket["key"]] = bucket["doc_count"]
        end
      end
    end

    @hits_over_time
  end

  def drilldown
    unless @drilldown
      @drilldown = []

      if(aggregations && aggregations["drilldown"])
        depth = @search.drilldown_depth
        descendent_depth = depth + 1

        aggregations["drilldown"]["buckets"].each do |bucket|
          if ApiUmbrellaConfig[:elasticsearch][:template_version] < 2
            parts = bucket["key"].split("/", 2)
            path = parts[1]
          else
            path = File.join([@search.drilldown_parent, bucket["key"]].compact)
          end

          descendent_prefix = File.join(descendent_depth.to_s, path)
          terminal = !path.end_with?("/")

          @drilldown << {
            :depth => depth,
            :path => path,
            :terminal => terminal,
            :descendent_prefix => descendent_prefix,
            :hits => bucket["doc_count"],
          }
        end
      end
    end

    @drilldown
  end

  def map_breadcrumbs
    if(!@map_breadcrumbs && @search.region)
      @map_breadcrumbs = []

      case(@search.region)
      when /^([A-Z]{2})$/
        country = Regexp.last_match[1]

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :name => ISO3166::Country.new(country).name },
        ]
      when /^(US)-([A-Z]{2})$/
        country = Regexp.last_match[1]
        state = Regexp.last_match[2]

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :region => country, :name => ISO3166::Country.new(country).name },
          { :name => ISO3166::Country.new(country).states[state]["name"] },
        ]
      end
    end

    @map_breadcrumbs
  end

  def cities
    unless @cities
      @cities = {}

      if(aggregations && aggregations["regions"])
        @regions = aggregations["regions"]["buckets"]
        if(@search.query[:aggregations][:regions][:terms][:field] == "request_ip_city")
          @city_names = @regions.map { |bucket| bucket["key"] }
          @cities = {}

          if @city_names.any?
            cities = LogCityLocation.where(:country => @search.country)
            if @search.state
              cities = cities.where(:region => @search.state)
            end
            cities = cities.where(:city.in => @city_names)

            cities.each do |city|
              @cities[city.city] = {
                "lat" => city.location["coordinates"][1],
                "lon" => city.location["coordinates"][0],
              }
            end
          end
        end
      end
    end

    @cities
  end
end
