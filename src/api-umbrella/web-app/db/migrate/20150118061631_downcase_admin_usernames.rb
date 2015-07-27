class DowncaseAdminUsernames < Mongoid::Migration
  def self.up
    Admin.all.each do |admin|
      admin.username = admin.username.downcase
      admin.save!(:validate => false)
    end
  end

  def self.down
  end
end
