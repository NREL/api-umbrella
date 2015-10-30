class GenerateAdminAuthenticationTokens < Mongoid::Migration
  def self.up
    Admin.all.each do |admin|
      admin.send(:generate_authentication_token)
      admin.save!
    end
  end

  def self.down
  end
end
