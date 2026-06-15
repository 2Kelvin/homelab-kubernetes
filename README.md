# Kubernetes Homelab

My Kubernetes homelab built using `Incus` and `K3s`. Due to limited PC resources I use system containers instead of VMs. My cluster is a `3 node K3s cluster`: my Arch linux PC is the control plane while the 2 incus system containers are the worker nodes.

## Setup (Arch Linux)

Similar setup could be achieved on other distros. For Ubuntu, setup using `LXD`.

### Install `incus`

```bash
sudo pacman -Syu incus
```

User setup and `incus` service startup

```bash
# give user root privileges to run incus automatically
# then reload shell instantly
sudo usermod -aG incus-admin $USER
newgrp incus-admin

# running the service/socket
sudo systemctl enable --now incus.socket
sudo systemctl enable --now incus.service

# accept all the defaults when setting this up or use the incus-preseed.yaml file
incus admin init
```

### Fixing Setup Errors

- **Error**: Failed instance creation: Failed creating instance record: Failed initializing instance: System doesn't have a functional idmap setup.

  Fix:

  ```bash
  # allocating system root process slots for incus instances (system containers & VMs)
  echo "root:1000000:1000000000" | sudo tee -a /etc/subuid /etc/subgid
  sudo systemctl restart incus.service
  ```

### Create Kubernetes Worker Nodes (Incus System Containers)

Creating 2 worker nodes for the Kubernetes Cluster. I'll use `incus system containers` rather than VMs since they are more resource efficient; they share my Linux Kernel.

```bash
incus launch images:ubuntu/26.04/cloud node1 < sys-container.yaml
incus launch images:ubuntu/26.04/cloud node2 < sys-container.yaml
```

### Install `K3s` and Setup Cluster

**IMPORTANT**: Disable swap memory.

- Since am using my personal PC for the cluster, I chose not to disable Arch Linux's Zram Swap to avoid system performance hits.

#### K3s Server Setup (Control Plane)

To install `K3s server`, it should be as easy as to run this:

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule
```

But due to my unique cluster setup, this is what I used:

1. I first fetched my Incus Bridged Network Default Gateway IP and assigned it to an environment variable for reuse:
   ```bash
   INCUS_IP=$(ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
   ```
   This is the IP that the incus nodes will use to communicate to my arch control plane PC and vice versa.

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - \
  --bind-address="$INCUS_IP" \
  --advertise-address="$INCUS_IP" \
  --node-ip="$INCUS_IP" \
  --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule
```

- `K3S_KUBECONFIG_MODE="644"` gives `kubectl` command admin priviliges without having to type _sudo kubectl_ all the time to manage the K3s cluster.
- `ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1` fetches my **incus bridged network** IP labelled as `incusbr0`.
- `bind-address` specifically attaches the **incusbr0** IP to the control plane; instead of letting my actual PC IP address from the router get attached to the control plane, making it impossible for incus nodes to talk to the control plane and vice versa.
- `advertise-address` hands the incus nodes the **incusbr0** IP to communicate to the control plane.
- `node-ip` is for kubelet and k8s to know which network to look at; points to **incusbr0** network.
- `--node-taint node-role.kubernetes.io/control-plane=true:NoSchedule` makes my arch linux (control plane) not accept any pods/deployments; it's strictly a control plane. All deployments should be assigned to the worker nodes. It only accepts essential control plane addons, like CoreDNS/network pods.

Confirm `K3s server` installation was successful:

```bash
kubectl get nodes -o wide
```

Confirm also that the taint was applied successfully:

```bash
kubectl describe node | grep -i taints
```

- In **kubectl get nodes -o wide** command output; the **ROLES** section should only have **control-plane**.

#### K3s Agents Setup (Nodes)

1. First, get the `K3s token` to be used to authenticate the K3s agents to the K3s server. Run this command in the K3s Server/Control Plane and copy the output:

   ```bash
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

- You'll paste this in the `K3S_TOKEN=` environment variable in the joining to the cluster step.

2. Fetch the K3s server IP. In my case, it's the `incusbr0` private bridged network I had fetched earlier and assigned the **INCUS_IP** environment variable.

3. Setup the 2 incus system containers as `K3s agents` (nodes) by running this command on each of them to join the K3s cluster:

   In my case, the `K3S_URL` server IP is my `INCUS_IP`.

   ```bash
   incus exec node1 -- curl -sfL https://get.k3s.io | K3S_URL=https://k3s_server_ip:6443 K3S_TOKEN=<k3s_node_token> sh -
   ```

Repeat step 3 to join **node2** to the cluster. Remember to change name from node1 to node2.

4. Verify your complete K3s cluster:

   ```bash
   kubectl get nodes -o wide
   ```
