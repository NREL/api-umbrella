object false

node :hits_over_time do
  @result.hits_over_time.map do |time, count|
    {
      :c => [
        { :v => time , :f => formatted_interval_time(time) },
        { :v => count, :f => number_with_delimiter(count) },
      ]
    }
  end
end
