class LogResult
  attr_reader :raw_result
  delegate :total, :results, :facets, :to => :raw_result

  def initialize(search, raw_result)
    @search = search
    @raw_result = raw_result
  end

  def interval_hits
    if(!@interval_hits && @raw_result.facets[:interval_hits])
      @interval_hits = {}

      # Default all interval points to 0 (so in case any are missing from the
      # real data).
      time = @search.start_time
      case @search.interval
      when "minute"
        time = time.change(:sec => 0)
      else
        time = time.send(:"beginning_of_#{@search.interval}")
      end

      while(time <= @search.end_time)
        @interval_hits[time.to_i * 1000] ||= 0
        time += 1.send(:"#{@search.interval}")
      end

      # Overwrite the default 0 values with the real values.
      @raw_result.facets[:interval_hits][:entries].each do |entry|
        @interval_hits[entry[:time]] = entry[:count]
      end
    end

    @interval_hits
  end

  def map_breadcrumbs
    if(!@map_breadcrumbs && @search.region)
      @map_breadcrumbs = []

      case(@search.region)
      when /^([A-Z]{2})$/
        country = $1

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :name => Country[country].name },
        ]
      when /^(US)-([A-Z]{2})$/
        country = $1
        state = $2

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :region => country, :name => Country[country].name },
          { :name => Country[country].states[state]["name"] },
        ]
      end
    end

    @map_breadcrumbs
  end

  def users_by_id
    unless @users_by_id
      user_ids = @raw_result.results.map { |result| result[:user_id] }
      if @raw_result.facets[:user_id]
        user_ids += @raw_result.facets[:user_id][:terms].map { |term| term[:term] }
      end

      @users_by_id = ApiUser.where(:_id.in => user_ids).all.to_a.group_by { |user| user.id.to_s }
    end

    @users_by_id
  end

  def cities
    unless @cities
      @cities = {}

      @regions = @raw_result.facets[:regions][:terms]
      if(@search.query[:facets][:regions][:terms][:field] == "request_ip_city")
        @city_names = @regions.map { |term| term[:term] }
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

          @search.server.index("api-umbrella").search({ :size => 500 }, query).results.each do |result|
            @cities[result[:city]] = result[:location]
          end
        end
      end
    end

    @cities
  end
end

=begin
    user_ids = @result.facets[:user_id][:terms].map { |term| term[:term] }
    user_ids += @result.results.map { |result| result[:user_id] }
    @users = ApiUser.where(:_id.in => user_ids).all.to_a.group_by { |user| user.id.to_s }
    @result.results.each do |result|
      if @users[result[:user_id]]
        user = @users[result[:user_id]].first
        result[:email] = user.email
      end
    end

    @result.facets[:user_id][:terms].each do |term|
      if @users[term[:term]]
        user = @users[term[:term]].first
        term[:term] = user.email
      end
    end

    @result.facets[:response_status][:terms].each do |term|
      name = Rack::Utils::HTTP_STATUS_CODES[term[:term].to_i]
      if(name)
        term[:term] = "#{term[:term]} (#{name})"
      end
    end
=end
