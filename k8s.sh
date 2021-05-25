#!/bin/bash

UBUNTU_VERSION=20.04
K8S_VERSION=1.19.2-00
node_type=master
LAYER=0
IP=$(curl ifconfig.co)

echo "Ubuntu version: ${UBUNTU_VERSION}"
echo "K8s version: ${K8S_VERSION}"
echo "K8s node type: ${node_type}"
echo
#Update all installed packages.
sudo apt-get update -y 
sudo apt-get upgrade -y 

#if you get an error similar to
#'[ERROR Swap]: running with swap on is not supported. Please disable swap', disable swap:
sudo swapoff -a

# install some utils
 sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

#Install Docker
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable"

 sudo apt-get update
 sudo apt-get install -y docker.io

#Install NFS client
 sudo apt-get install -y nfs-common

#Enable docker service
sudo  systemctl enable docker.service

#Update the apt source list
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
 add-apt-repository "deb [arch=amd64] http://apt.kubernetes.io/ kubernetes-xenial main"

#Install K8s components
 sudo apt-get update
sudo apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION

 sudo apt-mark hold kubelet kubeadm kubectl

#Initialize the k8s cluster
 sudo kubeadm init --pod-network-cidr=10.244.0.0/16

sudo sleep 60

#Create .kube file if it does not exists
sudo mkdir -p $HOME/.kube

#Move Kubernetes config file if it exists
if [ -f $HOME/.kube/config ]; then
    mv $HOME/.kube/config $HOME/.kube/config.back
fi

 sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


#untaint the node so that pods will get scheduled:
sudo kubectl taint nodes --all node-role.kubernetes.io/master-

#Install Calico network
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f calico.yml

sleep 60
kubectl get node
#   Install Helm 
    sudo chmod 700 helm.sh
    sudo ./helm.sh

# install MetalLB
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system
kubectl apply -f metallb_namespace.yml
kubectl apply -f metallb.yml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl create -f metallb_configmap.yml 
kubectl -n metallb-system get all 
# Install Gloo

sudo kubectl create namespace gloo-system
cp  gloo_offline_values.yaml  gloo/
cd gloo
cp ../gloo_offline_values.yaml  gloo
sudo helm install gloo . .  --namespace gloo-system
kubectl -n  gloo-system get all 
sudo  cd ..
