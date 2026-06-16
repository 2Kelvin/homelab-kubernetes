#!bin/bash

incus exec node-vm -- sudo k3s-uninstall.sh 
incus exec node-vm -- sudo rm -rf /etc/rancher /var/lib/rancher /var/log/pods /var/log/containers

sudo cat /var/lib/rancher/k3s/server/node-token

INCUS_IP=$(ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
echo $INCUS_IP

# replace k3s_server_ip & k3s_node_token with necessary values
# sh -c '' help pass and run the whole command in node-vm
incus exec node-vm -- sh -c 'curl -sfL https://get.k3s.io | K3S_URL=https://k3s_server_ip:6443 K3S_TOKEN=<k3s_node_token> sh -'

kubectl get nodes -o wide
