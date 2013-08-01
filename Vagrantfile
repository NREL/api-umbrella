# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  box_arch = if(RUBY_PLATFORM =~ /64/) then "x86_64" else "i386" end
  is_windows = (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)

  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "CentOS-6.4-#{box_arch}-v20130731"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-#{box_arch}-v20130731.box"

  # Boot with a GUI so you can see the screen. (Default is headless)
  # config.vm.boot_mode = :gui

  # Assign a hostname unique to this project.
  config.vm.hostname = "api.vagrant"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, ip: "10.10.10.2"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder ".", "/vagrant", :nfs => !is_windows

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider :virtualbox do |vb|
    # Adjust memory used by the VM.
    vb.customize ["modifyvm", :id, "--memory", 2048]
    vb.customize ["modifyvm", :id, "--cpus", 2]

    # Disable DNS proxy. FIXME? It seems like this should be
    # on, but enabling it results in a 5 second delay for any
    # HTTP requests.
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
  end
  
  # Our site's nginx config files resides on the /vagrant share. Since this
  # isn't mounted at boot time, always restart things after the server and
  # shares are completely up.
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
    chef.add_role "api_umbrella_log_base"
    chef.add_role "api_umbrella_router_vagrant"
    chef.add_role "api_umbrella_web_vagrant"
  end
end
