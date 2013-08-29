 Mongoid::Userstamp.configure do |c|
   c.user_reader = :current_admin
   c.user_model = :admin
 end
