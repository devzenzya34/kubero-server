# -*- mode: ruby -*-
#vi: set ft-ruby

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.box_check_update = false
  config.vm.box = "bento/ubuntu-24.04"

  # Provision SSH key
  config.vm.provision "shell" do |s|
    ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
    s.inline = <<-SHELL
    mkdir -p /home/vagrant/.ssh
    echo #{ssh_pub_key} >> /home/vagrant/.ssh/authorized_keys
    chmod 600 /home/vagrant/.ssh/authorized_keys
    SHELL
  end

  # Define the manager node
  (1..1).each do |i|
    config.vm.define "man#{i}" do |man|
      man.vm.hostname = "kubero-man#{i}"
      man.vm.network "private_network", ip: "192.168.56.10#{i}" # Private network for internal communication
      man.vm.network "public_network", ip: "192.168.1.20#{i}", bridge: "enp3s0" # Bridged network for external access
      man.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
      end
    end
  end

  # Define the worker nodes
  (1..2).each do |i|
    config.vm.define "work#{i}" do |work|
      work.vm.hostname = "kubero-work#{i}"
      work.vm.network "private_network", ip: "192.168.56.11#{i}" # Private network for internal communication
      work.vm.network "public_network", ip: "192.168.1.21#{i}", bridge: "enp3s0" # Bridged network for external access
      work.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
      end
    end
  end

  # Add hostname resolution
  config.vm.provision "shell", inline: <<-SHELL
    echo "192.168.56.201 kubero-man1" | sudo tee -a /etc/hosts
    echo "192.168.56.211 kubero-work1" | sudo tee -a /etc/hosts
    echo "192.168.56.212 kubero-work2" | sudo tee -a /etc/hosts
  SHELL
end
