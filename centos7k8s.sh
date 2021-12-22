#!/bin/bash

kube::init(){
export master-hostname="master-node"
export hosts=$(cat <<EOF
192.168.1.211 master-node
192.168.1.212 node-1
EOF
)
}


kube::master(){
kube::init
echo $master-hostname
sudo hostnamectl set-hostname $master-hostname
sudo cat /etc/hostname
sudo kubeadm config images pull
sudo kubeadm reset -f
sudo kubeadm init \
  --pod-network-cidr=10.1.0.0/16 \
  --upload-certs \
  --control-plane-endpoint=master-node
sudo mkdir -p $HOME/.kube
sudo rm -r $HOME/.kube/config -f
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export kubever=$(sudo kubectl version | base64 | tr -d '\n')
sudo kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
sudo kubectl get nodes
}


k8s::install_prerequisites(){
echo  $hosts
sudo cat <<EOF> /etc/hosts
$hosts  
EOF
sudo cat  /etc/hosts
sudo systemctl stop firewalld
sudo systemctl disable --now firewalld
sudo setenforce 0
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
sudo cat /etc/sysconfig/selinux
sudo modprobe overlay
sudo modprobe br_netfilter
sudo lsmod | grep br_netfilter
sudo lsmod | grep overlay
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo cat /etc/sysctl.d/kubernetes.conf
sudo sysctl --system
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
sudo cat /etc/fstab
#sudo hostnamectl set-hostname master-node
#sudo exec bash
}


k8s::install_docker(){
# Install packages
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io -y
# Create required directories
sudo mkdir /etc/docker
sudo mkdir -p /etc/systemd/system/docker.service.d
# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
sudo cat  /etc/docker/daemon.json
# Start and enable Services
sudo systemctl daemon-reload 
sudo systemctl restart docker
sudo systemctl enable docker
sudo systemctl status docker
sudo docker --version
}
k8s::install_kubeadm(){
sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo yum upgrade -y
sudo yum update -y
sudo yum install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet
sudo systemctl start kubelet
sudo systemctl status kubelet
}

kube::uninstall(){
sudo kubeadm reset -f
sudo systemctl stop docker.socket
sudo systemctl stop docker
sudo systemctl disable docker
sudo yum remove -y docker-ce docker-ce-cli containerd.io 
sudo yum remove -y yum-utils device-mapper-persistent-data lvm2
sudo systemctl stop kubelet
sudo systemctl disable kubelet
sudo yum remove -y kubelet kubeadm kubectl
}


kube::install(){
#kube::uninstall
kube::init
k8s::install_prerequisites
k8s::install_docker
k8s::install_kubeadm
}

main(){
     case $1 in
    "up" )
        kube::install
        ;;
    "master" )
        kube::master
        ;;
    "down" )
        kube::uninstall
        ;;
    *)
        echo "usage: $0 up | master | down "
        echo "       $0 up to install"
        echo "       $0 master to activate master"
        echo "       $0 down to tear all down ,inlude all data! so becarefull"
        echo "       unkown command $0 $@"
        ;;
    esac
}

main $@
