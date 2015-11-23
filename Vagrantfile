# -*- mode: ruby -*-
# vi: set ft=ruby :

plugins = { "vagrant-berkshelf" => nil }

plugins.each do |plugin, version|
  unless(Vagrant.has_plugin?(plugin))
    error = "The '#{plugin}' plugin is not installed. Try running:\n"
    error << "vagrant plugin install #{plugin}"
    error << " --plugin-version #{version}" if(version)
    raise error
  end
end

# Allow picking a different Vagrant base box:
# API_UMBRELLA_VAGRANT_BOX="chef/debian-7.4" vagrant up
BOX = ENV["API_UMBRELLA_VAGRANT_BOX"] || "nrel/CentOS-6.7-x86_64"

# Allow adjusting the memory and cores when starting the VM:
MEMORY = (ENV["API_UMBRELLA_VAGRANT_MEMORY"] || "2048").to_i
CORES = (ENV["API_UMBRELLA_VAGRANT_CORES"] || "2").to_i

# Allow a different IP
IP = ENV["API_UMBRELLA_VAGRANT_IP"] || "10.10.33.2"

# Allow NFS file sharing to be disabled
if(Vagrant::Util::Platform.windows?)
  NFS = false
else
  NFS = (ENV["API_UMBRELLA_VAGRANT_NFS"] || "true") == "true"
end

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = BOX

  # Boot with a GUI so you can see the screen. (Default is headless)
  # config.vm.boot_mode = :gui

  # Assign a hostname unique to this project.
  config.vm.hostname = "api.vagrant"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, :ip => IP

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder ".", "/vagrant", :nfs => NFS

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider :virtualbox do |vb|
    # Adjust memory used by the VM.
    vb.customize ["modifyvm", :id, "--memory", MEMORY]
    vb.customize ["modifyvm", :id, "--cpus", CORES]

    # Keep the virtual machine's clock better in sync to prevent drift (by
    # default VirtualBox only syncs if the clocks get more than 20 minutes out
    # of sync).
    vb.customize ["guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000]
  end

  # Use the user's local SSH keys for git access.
  config.ssh.forward_agent = true

  # Enable provisioning with chef solo, specifying a cookbooks path, roles
  # path, and data_bags path (all relative to this Vagrantfile), and adding
  # some recipes and/or roles.
  config.vm.provision :chef_solo do |chef|
    chef.run_list = [
      "recipe[api-umbrella::development]",
    ]
  end
end
