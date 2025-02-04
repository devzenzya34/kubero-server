#!/bin/bash

# Exit on any error
set -e

echo "Starting Kubernetes installation..."

# Disable swap
sudo swapoff -a
# Comment out swap entries in /etc/fstab
sudo sed -i '/swap/s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set required sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters
sudo sysctl --system

# Install required packages
sudo apt-get update
sudo apt-get install -y apt-transport-https

# Add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt-get update

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl

# Pin the versions to prevent unexpected upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# Enable and start kubelet service
sudo systemctl enable --now kubelet

# Configure containerd for Kubernetes
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

echo "Kubernetes components installation completed!"
echo "To initialize the control plane node, run:"
echo "sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
echo ""
echo "After initialization, follow the instructions provided by kubeadm to:"
echo "1. Set up kubeconfig"
echo "2. Install a CNI network plugin (like Calico or Flannel)"
echo "3. Join worker nodes (if any)"