# Setup Kubernetes Cluster v.1.31 RHEL
<img src="https://cdn.worldvectorlogo.com/logos/red-hat.svg" alt="K8s kubeadm tool" height="200"><img src="https://kubernetes.io/images/kubeadm-stacked-color.png" alt="K8s kubeadm tool" height="200">

## Step 1. Set SELinux on Permisive Mode
  # Set SELinux in permissive mode (effectively disabling it)
  ```
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  ```

## Step 2. Disable Swap Memory 
  ```
  sudo swapoff -a
  ```
