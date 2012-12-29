# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  box_arch = if(RUBY_PLATFORM =~ /64/) then "x86_64" else "i386" end
  is_windows = (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)

  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "CentOS-6.3-#{box_arch}-v20121228"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.3-#{box_arch}-v20121228.box"

  # Boot with a GUI so you can see the screen. (Default is headless)
  # config.vm.boot_mode = :gui

  # Assign a hostname unique to this project.
  config.vm.host_name = "api.vagrant"

  # Assign this VM to a host-only network IP, allowing you to access it
  # via the IP. Host-only networks can talk to the host machine as well as
  # any other machines on the same network, but cannot be accessed (through this
  # network interface) by any external networks.
  config.vm.network :hostonly, "10.10.10.2"

  # Assign this VM to a bridged network, allowing you to connect directly to a
  # network using the host's network device. This makes the VM appear as another
  # physical device on your network.
  # config.vm.network :bridged

  # Forward a port from the guest to the host, which allows for outside
  # computers to access the VM, whereas host only networking does not.
  config.vm.forward_port 80, 8080

  # Share an additional folder to the guest VM. The first argument is
  # an identifier, the second is the path on the guest to mount the
  # folder, and the third is the path on the host to the actual folder.
  config.vm.share_folder "v-root", "/vagrant", ".", :nfs => !is_windows

  # Our site's haproxy and nginx config files resides on the /vagrant share.
  # Since this isn't mounted at boot time, always restart things after the
  # server and shares are completely up.
  config.vm.provision :shell, :inline => "if [ -f /etc/init.d/haproxy ]; then /etc/init.d/haproxy restart; fi"
  config.vm.provision :shell, :inline => "if [ -f /etc/init.d/nginx ]; then /etc/init.d/nginx restart; fi"
  config.vm.provision :shell, :inline => "mkdir -p /srv/sites && chown vagrant /srv/sites"

  # Enable provisioning with chef solo, specifying a cookbooks path, roles
  # path, and data_bags path (all relative to this Vagrantfile), and adding 
  # some recipes and/or roles.
  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = "chef/cookbooks"
    chef.roles_path = "chef/roles"
    chef.data_bags_path = "chef/data_bags"

    #chef.log_level = :debug

    chef.add_role "api_umbrella_db_vagrant"
    chef.add_role "api_umbrella_router_vagrant"
    chef.add_role "api_umbrella_web_vagrant"
  end

  # Adjust memory used by the VM.
  config.vm.customize ["modifyvm", :id, "--memory", 1024]

  # Disable DNS proxy. FIXME? It seems like this should be
  # on, but enabling it results in a 5 second delay for any
  # HTTP requests.
  config.vm.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
end
