object false

node :interval_hits do
  @result.interval_hits.map do |time, count|
    {
      :c => [
        { :v => time , :f => formatted_interval_time(time) },
        { :v => count, :f => number_with_delimiter(count) },
      ]
    }
  end
end
