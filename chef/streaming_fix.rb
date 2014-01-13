# FIXME: Temporary workaround for chef logging in Vagrant:
# https://tickets.opscode.com/browse/CHEF-4725
::Chef::Config.from_string("log_location STDOUT", "chef/streaming_fix.rb")
