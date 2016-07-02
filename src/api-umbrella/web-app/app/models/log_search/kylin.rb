class LogSearch::Kylin < LogSearch::Sql
  def execute_kylin(sql)
    @kylin_conn ||= Faraday.new(:url => "#{ApiUmbrellaConfig[:kylin][:protocol]}://#{ApiUmbrellaConfig[:kylin][:host]}:#{ApiUmbrellaConfig[:kylin][:port]}") do |faraday|
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
      faraday.basic_auth "ADMIN", "KYLIN"
    end
    if(ApiUmbrellaConfig[:kylin][:auth])
      @kylin_conn.basic_auth(ApiUmbrellaConfig[:kylin][:auth][:username], ApiUmbrellaConfig[:kylin][:auth][:password])
    end

    Rails.logger.info(sql)
    response = @kylin_conn.post do |req|
      req.url "/kylin/api/query"
      req.headers["Content-Type"] = "application/json"
      req.body = MultiJson.dump({
        :acceptPartial => false,
        :project => "api_umbrella",
        :sql => sql,
      })
    end

    if(response.status != 200)
      Rails.logger.error(response.body)
      raise "Kylin Error"
    end

    MultiJson.load(response.body)
  end

  def execute_presto(sql)
    @presto_conn ||= Faraday.new(:url => "#{ApiUmbrellaConfig[:presto][:protocol]}://#{ApiUmbrellaConfig[:presto][:host]}:#{ApiUmbrellaConfig[:presto][:port]}") do |faraday|
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end
    if(ApiUmbrellaConfig[:presto][:auth])
      @presto_conn.basic_auth(ApiUmbrellaConfig[:presto][:auth][:username], ApiUmbrellaConfig[:presto][:auth][:password])
    end

    Rails.logger.info(sql)
    response = @presto_conn.post do |req|
      req.url "/v1/statement"
      req.headers["Content-Type"] = "text/plain"
      req.headers["X-Presto-User"] = "presto"
      req.headers["X-Presto-Catalog"] = "hive"
      req.headers["X-Presto-Schema"] = "default"
      if(@options[:query_timeout])
        req.headers["X-Presto-Session"] = "query_max_run_time=#{@options[:query_timeout]}"
      end
      req.body = sql
    end

    results = {
      "columnMetas" => [],
      "results" => [],
    }
    while(response.status == 200)
      query_result = MultiJson.load(response.body)
      if(query_result["stats"] && query_result["stats"]["state"] == "FAILED")
        Rails.logger.error(response.body)
        raise "Presto Error"
      end

      if(results["columnMetas"].empty? && query_result["columns"])
        results["columnMetas"] = query_result["columns"].map do |column|
          {
            "label" => column["name"],
          }
        end
      end

      if(query_result["data"].present?)
        results["results"] += query_result["data"]
      end

      if(query_result["nextUri"])
        response = @presto_conn.get do |req|
          req.url(query_result["nextUri"])
        end
      else
        break
      end
    end

    if(response.status != 200)
      Rails.logger.error(response.body)
      raise "Presto Error"
    end

    results
  end

  def execute_query(query_name, query = {})
    unless @query_results[query_name]
      sql = build_query(query)

      if(@needs_presto)
        results = execute_presto(sql)
      else
        begin
          results = execute_kylin(sql)
        rescue
          results = execute_presto(sql)
        end
      end

      @query_results[query_name] = results
    end

    @query_results[query_name]
  end
end
