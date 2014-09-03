class LogResult
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

  def facets
    raw_result["facets"]
  end

  def aggregations
    raw_result["aggregations"]
  end

  def hits_over_time
    if(!@hits_over_time && aggregations["hits_over_time"])
      @hits_over_time = {}

      aggregations["hits_over_time"]["buckets"].each do |bucket|
        @hits_over_time[bucket["key"]] = bucket["doc_count"]
      end
    end

    @hits_over_time
  end

  def map_breadcrumbs
    if(!@map_breadcrumbs && @search.region)
      @map_breadcrumbs = []

      case(@search.region)
      when /^([A-Z]{2})$/
        country = Regexp.last_match[1]

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :name => Country[country].name },
        ]
      when /^(US)-([A-Z]{2})$/
        country = Regexp.last_match[1]
        state = Regexp.last_match[2]

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :region => country, :name => Country[country].name },
          { :name => Country[country].states[state]["name"] },
        ]
      end
    end

    @map_breadcrumbs
  end

  def cities
    unless @cities
      @cities = {}

      @regions = facets["regions"]["terms"]
      if(@search.query[:facets][:regions][:terms][:field] == "request_ip_city")
        @city_names = @regions.map { |term| term["term"] }
        @cities = {}

        if @city_names.any?
          query = {
            :filter => {
              :and => [],
            },
          }

          query[:filter][:and] << {
            :term => { :country => @search.country },
          }

          if @search.state
            query[:filter][:and] << {
              :term => { :region => @search.state },
            }
          end

          query[:filter][:and] << {
            :terms => { :city => @city_names },
          }

          @search.server.index("api-umbrella").search({ :size => 500 }, query).documents.each do |result|
            @cities[result["city"]] = result["_source"]["location"]
          end
        end
      end
    end

    @cities
  end
end
