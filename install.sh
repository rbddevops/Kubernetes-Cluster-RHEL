#!/bin/bash

# Script to set up Kubernetes Cluster v1.31 on RHEL

# Step 1. Remove older versions of Docker and related packages
sudo dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc

# Step 2. Disable SELinux and Firewalld
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo systemctl status firewalld

# Step 3. Disable swap memory for all nodes
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Step 4. Enable Kernel Modules and Settings
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Step 5. Install Containerd Runtime
sudo dnf install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io
sudo systemctl enable --now containerd

# Configure containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Edit containerd config to set systemd as cgroup driver (manual step)
sudo vi /etc/containerd/config.toml  # Modify SystemdCgroup=true
sudo systemctl restart containerd
sudo systemctl enable containerd --now

# Step 6. Add Kubernetes to yum repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Step 7. Install Kubelet, Kubeadm, and Kubectl
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet

# Step 8. Initialize Kubernetes Master Node (Controlplane)
sudo ip a  # Check ethernet IP address
sudo kubeadm init --apiserver-advertise-address=<master_ip> --pod-network-cidr=10.244.0.0/16  # Replace <master_ip> with the actual IP

# Step 9. Configure kubectl for the regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Step 10. Install Add-On for Pod Networking (Flannel, Calico..)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Join Worker Nodes
echo "To join worker nodes, run the following command:"
kubeadm token create --print-join-command

# Recommended Configurations

# Kubectl completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

# Configure vim editor
cat <<EOF | tee -a ~/.vimrc
set tabstop=2
set expandtab
set shiftwidth=2
EOF

# Set alias for Kubectl command
cat <<EOF | tee -a ~/.bashrc
alias k=kubectl
complete -o default -F __start_kubectl k
EOF

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Deploy Kubernetes Dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

# Deploy NGINX Ingress Controller

# Step 1. Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/cloud/deploy.yaml

# Step 2. Exposing the NGINX Ingress Controller
# Load Balancer
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/cloud/deploy.yaml

# Node Port
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/baremetal/deploy.yaml

# Step 3. Validate the NGINX Ingress Controller is running
kubectl get all -n ingress-nginx
