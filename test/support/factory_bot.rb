FactoryBot.find_definitions

module FactoryBot
  # Either return the results of FactoryBot.attributes_for or
  # FactirlBot.build for a given factory, depending on what the current
  # factory strategy is.
  #
  # The use case for this is to be called for nested association factory data,
  # so that when attributes_for is being used, the factory returns nested
  # hashes of data, but if create or build is being used, the factory returns
  # ActiveRecord objects (which ActiveRecord can then handle saving).
  #
  # This isn't the most standard way to handle embedded associations inside
  # FactoryBot, but it lets us leverage the same factories for both
  # building/creating records, as well as returning hashes of data in the
  # format expected of our APIs (for POST/PUT calls).
  def self.attributes_or_build(current_strategy, name, ...)
    if(current_strategy.kind_of?(FactoryBot::Strategy::AttributesFor))
      self.attributes_for(name, ...)
    else
      self.build(name, ...)
    end
  end
end
