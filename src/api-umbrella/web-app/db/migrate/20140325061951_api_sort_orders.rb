class ApiSortOrders < Mongoid::Migration
  def self.up
    apis = Api.sorted.all.to_a
    apis.each_with_index do |api, index|
      api.sort_order = index + 1
      api.save!
    end
  end

  def self.down
  end
end
