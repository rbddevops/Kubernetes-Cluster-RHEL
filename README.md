# Setup Kubernetes Cluster v.1.31 on RHEL
<img src="https://cdn.worldvectorlogo.com/logos/red-hat.svg" alt="K8s kubeadm tool" height="200"><img src="https://kubernetes.io/images/kubeadm-stacked-color.png" alt="K8s kubeadm tool" height="200">

## Step 1. Remove any older version of docker

```
sudo dnf remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc
```

## Step 2. Disable SELinux and Firewalld
  ```
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  ```
  ```
  sudo systemctl disable firewalld
  sudo systemctl disable firewalld
  ```

## Step 3. Disable swap memory for all nodes

  ```
  sudo swapoff -a
  sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  ```

## Step 4. Enable Kernel Modules and Settings

```
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

```
sudo modprobe overlay
sudo modprobe br_netfilter
```

```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
```
```
# Apply changes
sudo sysctl --system
```

## Step 5. Install Containerd Runtime

```
sudo dnf install -y containerd.io
sudo systemctl enable --now containerd
```

<h4>Create default config</h4>

```
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

<h4>Set systemd as cdgroup driver</h4>

```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

```
sudo systemctl restart containerd
sudo systemctl enable containerd
```

## Step 6. Add Kubernetes into yum repository

```
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF
```

## Step 7. Install Kubelet, Kubeadm and Kubectl

```
sudo dnf install -y kubelet-1.31.0 kubeadm-1.31.0 kubectl-1.31.0
```

<h4>Enable on Kubelet on startup</h4>

```
sudo systemctl enable --now kubelet
```

## Step 8. Initialize Kubernetes Master Node (Controlplane)

```
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version v1.31.0
```

## Step 9. Configure kubectl regular user
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Step 10. Install Calico Add-On for Pod Networking
```
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

## Step 12. Create token in order to join Worker nodes to the cluster
```
kubeadm token create --print-join-command

```

<h1>Install helm to help with app installations.</h1>

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```
