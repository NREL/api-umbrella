# -*- mode: ruby -*-
# vi: set ft=ruby :

options = {
  # Allow NFS file sharing to be disabled
  :nfs => (ENV["API_UMBRELLA_VAGRANT_NFS"] == "true") || !Vagrant::Util::Platform.windows?,

  # Allow picking a different Vagrant base box:
  # API_UMBRELLA_VAGRANT_BOX="chef/debian-7.4" vagrant up
  :box => ENV["API_UMBRELLA_VAGRANT_BOX"] || "nrel/CentOS-6.7-x86_64",

  # Allow adjusting the memory and cores when starting the VM:
  :memory => (ENV["API_UMBRELLA_VAGRANT_MEMORY"] || "2048").to_i,
  :cores => (ENV["API_UMBRELLA_VAGRANT_CORES"] || "2").to_i,

  # Allow a different IP
  :ip => ENV["API_UMBRELLA_VAGRANT_IP"] || "10.10.33.2",
}

plugins = { "vagrant-berkshelf" => nil }

plugins.each do |plugin, version|
  unless(Vagrant.has_plugin?(plugin))
    error = "The '#{plugin}' plugin is not installed. Try running:\n"
    error << "vagrant plugin install #{plugin}"
    error << " --plugin-version #{version}" if(version)
    raise error
  end
end

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = options[:box]

  # Boot with a GUI so you can see the screen. (Default is headless)
  # config.vm.boot_mode = :gui

  # Assign a hostname unique to this project.
  config.vm.hostname = "api.vagrant"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, :ip => options[:ip]

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder ".", "/vagrant", :nfs => options[:nfs]
  if(options[:nfs])
    config.nfs.map_uid = Process.uid
    config.nfs.map_gid = Process.gid
  end

  config.vm.synced_folder "src/api-umbrella/admin-ui", "/vagrant-admin-ui",
    :type => "rsync",
    :rsync__verbose => true,
    :rsync__exclude => [
      "tmp",
      "node_modules",
      "dist",
    ]

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider :virtualbox do |vb|
    # Adjust memory used by the VM.
    vb.customize ["modifyvm", :id, "--memory", options[:memory]]
    vb.customize ["modifyvm", :id, "--cpus", options[:cores]]

    # Keep the virtual machine's clock better in sync to prevent drift (by
    # default VirtualBox only syncs if the clocks get more than 20 minutes out
    # of sync).
    vb.customize ["guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000]
  end

  # Use the user's local SSH keys for git access.
  config.ssh.forward_agent = true

  # Provision the development environment with our Chef cookbook.
  config.vm.provision :chef_solo do |chef|
    chef.run_list = [
      "recipe[api-umbrella::development]",
    ]
  end

  # Always restart API Umbrella after starting the machine. This ensures the
  # development version get started from the /vagrant partition (since the
  # /vagrant NFS partition isn't started early enough during normal boot, we
  # must do this here).
  config.vm.provision :shell, :run => "always", :inline => <<-eos
    if [ -f /etc/init.d/api-umbrella ]; then
      /etc/init.d/api-umbrella restart
    fi
  eos
end
