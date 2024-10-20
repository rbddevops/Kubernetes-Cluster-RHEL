# Setup Kubernetes Cluster v.1.31 RHEL
<img src="https://cdn.worldvectorlogo.com/logos/red-hat.svg" alt="K8s kubeadm tool" height="200"><img src="https://kubernetes.io/images/kubeadm-stacked-color.png" alt="K8s kubeadm tool" height="200">

## Step 1. Disable SELinux, set permissive mode
  ```
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  ```

## Step 2. Disable swap memory for all nodes
  ```
  sudo swapoff -a
  sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  ```

## Step 3. Manually enable IPv4 packet forwarding

```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot

sudo sysctl --system
```

<h4>Verify that net.ipv4.ip_forward is set to 1 with:</h4>

```
sysctl net.ipv4.ip_forward
```


## Step 4. Install containerd 
<h4>Add docker gpg key and repository</h4>

```
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
```
<h4>Update packages and install containerd</h4>

```
apt-get update
apt-get install containerd.io -y
```
<h4>Configure containerd to use systemd as the cgroup driver to use systemd cgroups.</h4>

```
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
```

<h4>Update containerd to load the overlay and br_netfilter modules</h4>

```
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```

<h4>Update kernel network settings to allow traffic to be forwarded</h4>

```
cat << EOF | tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
```

<h4>Load kernel modules and verify containerd is running</h4>

```
modprobe overlay
modprobe br_netfilter
sysctl --system
```
```
systemctl status containerd
```

## Step 5. Add Kubernetes repository
```
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
```
```
apt-get update
apt-get install -y kubelet=1.31.*- kubeadm=1.31.3-1.1 kubectl=1.31.3-1.1
apt-mark hold kubelet kubeadm kubectl
```


## Step 6. Install kubelet, kubeadm and kubectl
```
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```
```
sudo systemctl enable --now kubelet
```
