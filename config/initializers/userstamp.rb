 Mongoid::Userstamp.config do |c|
   c.user_reader = :current_admin
   c.user_model = :admin

   c.updated_column_opts = { :type => String }
   c.created_column_opts = { :type => String }
 end
