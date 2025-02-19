#!/bin/bash

# filepath: /home/avinsc/eks/k8s-kubeadm/kubeadm.sh
# create a bash file with the following content
# 2 options master and worker
# master will install kubeadm, kubectl and kubelet
# worker will install kubeadm, kubectl and kubelet and join the master

set -E

# Function to install kubeadm, kubectl, and kubelet
install_kubernetes_tools() {
    echo "Update and Upgrade Ubuntu"
    sudo apt-get update -y
    # sudo apt-get upgrade -y
    echo "Disable Swap"
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "Add Kernel Parameters"
    sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
    sudo modprobe overlay
    sudo modprobe br_netfilter
    sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
    sudo sysctl --system
    echo "Install Containerd Runtime"
    sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
    sudo apt update
    sudo apt install -y containerd

    containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
    sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

    sudo systemctl restart containerd
    sudo systemctl enable containerd
    echo "Install Kubernetes Tools"
    sudo apt-get update
    # apt-transport-https may be a dummy package; if so, you can skip that package
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
}

# Function to initialize the master node
initialize_master() {
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

# Function to join the worker node to the master
join_worker() {
    read -p "Enter the join command provided by the master node: " JOIN_COMMAND
    sudo $JOIN_COMMAND
}

# Main script logic
if [ "$1" == "master" ]; then
    install_kubernetes_tools
    initialize_master
elif [ "$1" == "worker" ]; then
    install_kubernetes_tools
    join_worker
else
    echo "Usage: $0 {master|worker}"
    exit 1
fi

