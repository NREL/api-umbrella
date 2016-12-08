class Api::V1::AnalyticsController < Api::V1::BaseController
  include ActionView::Helpers::NumberHelper

  before_action :set_analytics_adapter
  skip_after_action :verify_authorized
  after_action :verify_policy_scoped
  around_action :set_time_zone

  def drilldown
    @search = LogSearch.factory(@analytics_adapter, {
      :start_time => params[:start_at],
      :end_time => params[:end_at],
      :interval => params[:interval],
    })
    policy_scope(@search)

    @search.search!(params[:search])
    @search.query!(params[:query])
    @search.filter_by_date_range!

    drilldown_size = if(request.format == "csv") then 0 else 500 end
    @search.aggregate_by_drilldown!(params[:prefix], drilldown_size)

    if(request.format != "csv")
      @search.aggregate_by_drilldown_over_time!(params[:prefix])
    end

    @result = @search.result

    respond_to do |format|
      format.csv
      format.json do
        @breadcrumbs = [
          :crumb => "All Hosts",
          :prefix => "0/",
        ]

        path = params[:prefix].split("/", 2)[1]
        parents = path.split("/")
        parents.each_with_index do |parent, index|
          @breadcrumbs << {
            :crumb => parent,
            :prefix => File.join((index + 1).to_s, parents[0..index].join("/"), "/"),
          }
        end

        @hits_over_time = {
          :cols => [
            { :id => "date", :label => "Date", :type => "datetime" },
          ],
          :rows => [],
        }

        @result.aggregations["top_path_hits_over_time"]["buckets"].each do |bucket|
          @hits_over_time[:cols] << {
            :id => bucket["key"],
            :label => bucket["key"].split("/", 2).last,
            :type => "number",
          }
        end

        has_other_hits = false
        @result.aggregations["hits_over_time"]["buckets"].each_with_index do |total_bucket, index|
          cells = [
            { :v => total_bucket["key"], :f => formatted_interval_time(total_bucket["key"]) },
          ]

          path_total_hits = 0
          @result.aggregations["top_path_hits_over_time"]["buckets"].each do |path_bucket|
            bucket = path_bucket["drilldown_over_time"]["buckets"][index]
            cells << { :v => bucket["doc_count"], :f => number_with_delimiter(bucket["doc_count"]) }
            path_total_hits += bucket["doc_count"]
          end

          other_hits = total_bucket["doc_count"] - path_total_hits
          cells << { :v => other_hits, :f => number_with_delimiter(other_hits) }

          @hits_over_time[:rows] << {
            :c => cells,
          }

          if(other_hits > 0)
            has_other_hits = true
          end
        end

        if(has_other_hits)
          @hits_over_time[:cols] << {
            :id => "other",
            :label => "Other",
            :type => "number",
          }
        else
          @hits_over_time[:rows].each do |row|
            row[:c].slice!(-1)
          end
        end
      end
    end
  end
end
