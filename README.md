# Setup Kubernetes Cluster

![Command](https://img.shields.io/badge/Linux_Distribution-RHEL-red)  ![Command](https://img.shields.io/badge/Tool-Kubeadm-blue)  ![Command](https://img.shields.io/badge/release-v1.31-blue) 

<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png" height="100"><img src="https://kubernetes.io/images/kubeadm-stacked-color.png" alt="K8s kubeadm tool" height="100"> 

<h2>Pre-requisites</h2>
<ul>
 <li>Root privileges</li>
 <li>Install Git package</li>
 <li>Set a Hostname for each Node</li>
 <li>Add IP Address and it's Hostname on  <span style="color: red;">/etc/hosts</span></li></span>
</ul>

  ```
  sudo dnf install -y openssh-server && dnf install -y git
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
```

```
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

<h2>Install Helm</h2>

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

<h2>Deploy Kubernetes Dashboard</h2>

```
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
```

```
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

<h2>Deploy NGINX Ingress Controller</h2>

<h4>Step 1. Install NGINX Ingress Controller</h4>

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/cloud/deploy.yaml
```

<h4>Step 2. Exposing the NGINX Ingress Controller</h4>

<h4>Load Balancer</h4>

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/cloud/deploy.yaml
```

<h4>Node Port</h4>

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/baremetal/deploy.yaml
```

<h4>Step 3. Validate the NGINX Ingress Controller is running</h4>

```
kubectl get all -n ingress-nginx
```

