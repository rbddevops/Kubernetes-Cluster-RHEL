#!/bin/bash

# Exit immediately if any command fails
set -e

# Step 1. Disable SELinux and set permissive mode
echo "Disabling SELinux..."
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Step 2. Disable swap memory
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Step 3. Enable IPv4 packet forwarding
echo "Enabling IPv4 packet forwarding..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
sysctl net.ipv4.ip_forward

# Step 4. Install containerd and dependencies
echo "Installing containerd..."

# Add docker gpg key and repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update packages and install containerd
sudo apt-get update
sudo apt-get install containerd.io -y

# Configure containerd to use systemd as the cgroup driver
echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Load the overlay and br_netfilter modules
echo "Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Update kernel network settings
cat << EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Apply changes
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl --system

# Check if containerd is running
sudo systemctl status containerd

# Step 5. Install Kubelet, Kubeadm, and Kubectl
echo "Installing Kubernetes components..."

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update packages and install Kubelet, Kubeadm, and Kubectl
sudo apt-get update
sudo apt-get install -y kubelet=1.31.*- kubeadm=1.31.3-1.1 kubectl=1.31.3-1.1

# Lock the versions
sudo apt-mark hold kubelet kubeadm kubectl

# Enable and start Kubelet
sudo systemctl enable --now kubelet

# Install Helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

echo "Kubernetes setup is complete."
