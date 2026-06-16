#!bin/bash

sudo k3s-uninstall.sh 
sudo rm -rf /etc/rancher /var/lib/rancher /var/log/pods /var/log/containers

INCUS_IP=$(ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
echo $INCUS_IP

curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - \
  --bind-address="$INCUS_IP" \
  --advertise-address="$INCUS_IP" \
  --node-ip="$INCUS_IP" \
  --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule

kubectl get nodes -o wide
