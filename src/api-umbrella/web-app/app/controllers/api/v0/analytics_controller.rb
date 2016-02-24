class Api::V0::AnalyticsController < Api::V1::BaseController
  skip_before_filter :authenticate_admin!, :only => [:summary]
  skip_after_filter :verify_authorized, :only => [:summary]

  def summary
    api_key_roles = request.headers['X-Api-Roles'].to_s.split(",")
    unless(api_key_roles.include?("api-umbrella-public-metrics"))
      render(:json => { :error => "You need to sign in or sign up before continuing." }, :status => :unauthorized)
      return false
    end

    # Try to fetch the summary data out of the cache.
    summary = Rails.cache.read("analytics_summary")

    # If it's not cached, generate it now.
    if(!summary || !summary[:cached_at])
      summary = generate_summary
      Rails.cache.write("analytics_summary", summary)

    # If it is cached, but it's stale, use the stale data, but create a thread
    # to refresh it asynchronously in the background. Since this takes a while
    # to generate, we want to err on the side of using the cache, so users
    # don't get a super slow response and we don't overwhelm the server when
    # it's uncached.
    elsif(summary && summary[:cached_at] && summary[:cached_at] < Time.now - 6.hours)
      Thread.new do
        Rails.cache.write("analytics_summary", generate_summary)
      end
    end

    headers["Access-Control-Allow-Origin"] = "*"
    respond_to do |format|
      format.json { render(:json => summary) }
    end
  end

  private

  def generate_summary
    summary = {
      :total_users => 0,
      :total_hits => 0,
      :users_by_month => [],
      :hits_by_month => [],
    }

    start_time = Time.parse("2013-07-01")

    # Fetch the user signups by month, trying to remove duplicate signups for
    # the same e-mail address (each e-mail address only gets counted for the first
    # month it signed up).
    users_by_month = ApiUser.collection.aggregate([
      {
        "$match" => {
          "created_at" => { "$exists" => true },
          "imported" => { "$in" => [nil, false] },
          "disabled_at" => { "$in" => [nil, false] },
        },
      },
      { "$sort" => { "created_at" => 1 } },
      { "$group" => { "_id" => { "email" => "$email" }, "created_at" => { "$first" => "$created_at" } } },
      { "$group" => { "_id" => { "year" => { "$year" => "$created_at" }, "month" => { "$month" => "$created_at" } }, "count" => { "$sum" => 1 } } },
      { "$sort" => { "_id.year" => 1, "_id.month" => 1 } },
    ])

    by_month = {}
    users_by_month.each do |users|
      by_month["#{users["_id"]["year"]}-#{users["_id"]["month"]}"] = {
        :year => users["_id"]["year"],
        :month => users["_id"]["month"],
        :count => users["count"],
      }

      summary[:total_users] += users["count"]
    end

    # Fill in missing months with 0 values.
    time = start_time
    while(time < Time.now)
      by_month["#{time.year}-#{time.month}"] ||= {
        :year => time.year,
        :month => time.month,
        :count => 0,
      }

      time += 1.month
    end

    # Now that we've 0-filled any missing months, add the data to the summary
    # and sort it.
    by_month.each do |key, value|
      summary[:users_by_month] << value
    end
    summary[:users_by_month].sort_by! { |data| [data[:year], data[:month]] }

    # Fetch the hits by month.
    search = LogSearch.new({
      :start_time => start_time,
      :end_time => Time.now,
      :interval => "month",
    })

    # Try to ignore some of the baseline monitoring traffic. Only include
    # successful responses.
    if(ApiUmbrellaConfig[:web][:analytics_v0_summary_filter].present?)
      search.search!(ApiUmbrellaConfig[:web][:analytics_v0_summary_filter])
    end

    search.exclude_imported!
    search.filter_by_date_range!
    search.aggregate_by_interval!
    search.limit!(1)

    result = search.result
    result.hits_over_time.sort.each do |key, value|
      time = Time.at(key / 1000)

      summary[:hits_by_month] << {
        :year => time.year,
        :month => time.month,
        :count => value,
      }

      summary[:total_hits] += value
    end

    summary[:cached_at] = Time.now
    summary
  end
end
