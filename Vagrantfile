# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

require './provision/speck'

# VM Speck
VMCFG = {
  NAME: VMC_NAME,
  USER: VMC_USER,
  MEM:  VMC_BUILD_MEMORY * 1024,
  CPU:  VMC_BUILD_CPU,
  VRAM: VMC_VRAM,
  HDD:  VMC_HDD,
}

# Check required plugins
REQUIRED_PLUGINS = [
  "vagrant-reload",
#  "vagrant-proxyconf",
]
exit unless REQUIRED_PLUGINS.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  ################################################################
  config.vm.box = "generic/ubuntu1804"
  ################################################################
  # config.vm.box = "ubuntu/bionic64"
  # with WSL
  #   cannot build, maybe used SCSI.
  ################################################################
  # config.vm.box = "hashicorp/bionic64"
  # with WSL
  #   vanila build sucsess
  ################################################################
  # config.vm.box = "bento/ubuntu-18.04"
  ################################################################

  # To shorter timeout 300 => 120
  config.vm.boot_timeout = 120
  # Setup machine.
  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.name = VMCFG[:NAME]
    vb.memory = VMCFG[:MEM]
    vb.customize ["modifyvm", :id,
                  "--cpus", VMCFG[:CPU],     # Use cpus.
                  "--vram", VMCFG[:VRAM],    # videomemory for fullscreen
                  "--graphicscontroller", "vmsvga", # use VMware graphics controller.
                  "--clipboard-mode", "bidirectional", # Clipboard shareing.
                  "--vrde", "off",   # Display->Remotedisplay->EnableServer = disable
                  "--uart1", "0x3F8", "4", # Enable serial port 1
                  "--uart2", "0x2F8", "3", # Enable serial port 2
                  "--uart3", "0x3E8", "4", # Enable serial port 3
                  # "--usbxhci", "on", # Enable USB 3.0
                  "--usbohci", "on", # Enable USB 1.1
                  "--ioapic", "on",  # Enable I/O ACIP
                  "--hwvirtex", "on",
                  "--nestedpaging", "on",
                  "--pae", "off",
                 ]
    vb.customize ["storagectl", :id,
                  "--name", "IDE Controller",
                  "--hostiocache", "off",
                 ]
  end

  # Network configulation (Need to setup).
  # config.vm.network "private_network", ip: "192.168.33.10"
  # Setup Shared direcotry (Need to setup).
  if defined? SHARED_DIR then
    config.vm.synced_folder ".", "/#{SHARED_DIR}", create: true
  end
  
  ################################################################
  # Begining provisioning scripts.
  ################################################################
  # Setup provision dirctory on guest.
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    mkdir -p /#{PROVD}
    chmod 1777 /#{PROVD}
    SHELL
  config.vm.provision "file", source: "#{PROVS}/common.sh", destination: "#{PROVD}/common.sh"
  config.vm.provision "file", source: "#{PROVS}/speck.rb", destination: "#{PROVD}/speck.rb"

  if "#{ENV['NO_PROVISION']}" == "" then
    if "#{ENV['EXPAND_PART']}" == "1" then
      # Provisioning apt update and install make.
      config.vm.provision "shell", name: "resize-part", privileged: true,
                          path: "#{PROVS}/guest-setup-root.sh",
                          upload_path: "#{PROVD}/provision.sh",
                          args: [ "expand_part" ]
      config.vm.provision :reload
    else
      # Setup environments.
      config.vm.provision "shell", name: "setup-machine", privileged: true,
                          path: "#{PROVS}/guest-setup-root.sh",
                          upload_path: "#{PROVD}/provision.sh",
                          args: [ "update",
                                  "setup_skel",
                                  "setup_locale",
                                  "install_desktop",
                                  "install_yocto_require",
                                  "add_user",
                                ]
    end
    # Customize build.
    if "#{ENV['BUILD']}" == "1" then
      config.vm.provision "shell", name: "build", privileged: true,
                        path: "#{PROVS}/guest-build-user.sh",
                        upload_path: "#{PROVD}/build.sh",
                        args: [ "download",
                                "configure",
                                "build",
                              ]
    end
    # Finalie box.
    if "#{ENV['FINALIZE']}" == "1" then
      config.vm.provision "shell", name: "finalize-machine", privileged: true,
                          path: "#{PROVS}/guest-setup-root.sh",
                          upload_path: "#{PROVD}/provision.sh",
                          args: [ "finish" ]
    end
  end
  # Sync for prepare power OFF.
  config.vm.provision "shell", name: "wait-sync", privileged: true,
                          path: "#{PROVS}/guest-setup-root.sh",
                          upload_path: "#{PROVD}/provision.sh",
                          args: [ "-f", "sync_sleep" ]
end
