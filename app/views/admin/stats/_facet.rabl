object false

node :rows do
  rows = locals[:facet][:terms].map do |term|
    { 
      :c => [
        { :v => term[:term] },
        { :v => term[:count], :f => number_with_delimiter(term[:count]) },
      ]
    }
  end

  if locals[:facet][:other] > 0
    rows << {
      :c => [
        { :v => "Other" },
        { :v => locals[:facet][:other], :f => number_with_delimiter(locals[:facet][:other]) },
      ]
    }
  end

  rows
end
