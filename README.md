# Setup Kubernetes Cluster v.1.31 on RHEL
<img src="https://cdn.worldvectorlogo.com/logos/red-hat.svg" alt="K8s kubeadm tool" height="150"><img src="https://kubernetes.io/images/kubeadm-stacked-color.png" alt="K8s kubeadm tool" height="150">

<h2>Pre-requisites</h2>
<ul>
 <li>Root privileges</li>
 <li>SSH package Installed</li>
 <li>Set a Hostname for each Node</li>
 <li>Add IP Address and it's Hostname on <span style="color: blue">/etc/hosts<span></li>
</ul>

  ```
  sudo dnf install openssh-server
  ```

  ```
  sudo hostnamectl set-hostname <hostname>
  ```

  ```
  sudo nano /etc/hosts
  ```

## Step 1. Remove older versions of docker

```
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
```

## Step 2. Disable SELinux and Firewalld
  ```
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  ```
  ```
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
  sudo systemctl status firewalld
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

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

## Step 5. Install Containerd Runtime

```
sudo dnf install -y yum-utils device-mapper-persistent-data lvm2
```

```
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

```
sudo dnf install -y containerd.io
sudo systemctl enable --now containerd
```

<h4>Configure containerd</h4>

```
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

<h4>Edit file at path /etc/containerd/config.toml and set systemd as cdgroup driver</h4>

```
sudo vi /etc/containerd/config.toml
```

```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

```
sudo systemctl restart containerd
sudo systemctl enable containerd --now
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
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```

## Step 7. Install Kubelet, Kubeadm and Kubectl

```
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```

<h4>Enable Kubelet on startup</h4>

```
sudo systemctl enable --now kubelet
```

## Step 8. Initialize Kubernetes Master Node (Controlplane)

```
sudo kubeadm config images pull
```

<h4>Check ethernet IP Address</h4>

```
sudo ip a
```

```
sudo kubeadm init --apiserver-advertise-address=192.168.137.144 --pod-network-cidr=10.244.0.0/16
```

## Step 9. Configure kubectl regular user
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## Step 10. Install Add-On for Pod Networking (Flannel, Calico..)
```
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

<h1>Join Worker Nodes</h1>

```
kubeadm token create --print-join-command
```

<h1>Recommended Configurations</h1>

<h4>Kubectl completion</h4>

```
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

<h4>Configure vim editor</h4>

```
cat <<EOF | tee -a ~/.vimrc
set tabstop=2
set expandtab
set shiftwidth=2
EOF
```

<h4>Set alias for Kubectl command</h4>

```
cat <<EOF | tee -a ~/.bashrc
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
```

<h4>Install Helm package for ease app installation</h4>

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```
