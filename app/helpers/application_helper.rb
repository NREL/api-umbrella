module ApplicationHelper
  def csv_time(time)
    if(time)
      time.utc.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end
