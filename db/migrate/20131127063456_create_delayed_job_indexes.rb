class CreateDelayedJobIndexes < Mongoid::Migration
  def self.up
    Delayed::Backend::Mongoid::Job.create_indexes
  end

  def self.down
  end
end
