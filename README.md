# Kubernetes Homelab

My Kubernetes homelab built using `Incus` and `K3s`. My cluster is a `2 node K3s cluster`; my Arch linux PC is the control plane while the incus Ubuntu VM is the node. This homelab has been built on **Arch Linux**. However, a similar setup could be achieved on other distros. For Ubuntu, setup using `LXD`.

## Incus Setup

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

### Create a Kubernetes Node (Incus VM)

I'm using an `incus VM` to create a node for the K3s Cluster.

```bash
incus launch images:ubuntu/26.04/cloud node-vm < incus/vm.yaml
```

## K3s Cluster Setup

### Install `K3s` and Setup a Kubernetes Cluster

**IMPORTANT**: Disable swap memory.

- Since am using my personal PC for the cluster, I chose not to disable Arch Linux's Zram Swap to avoid system performance hits.

#### K3s Server Setup (Control Plane)

Installing `K3s server`, is as easy as running this:

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule
```

But due to my unique setup, this is what I used:

I first fetched my Incus Bridged Network Default Gateway IP and assigned it to an environment variable for reuse. This is the IP that the incus node will use to communicate to my arch control plane PC and vice versa.

```bash
INCUS_IP=$(ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
```

Then ran this in my Control Plane/K3s Server (Arch PC):

```bash
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - \
  --bind-address="$INCUS_IP" \
  --advertise-address="$INCUS_IP" \
  --node-ip="$INCUS_IP" \
  --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule
```

Arguments explanations:

- `ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1` fetches my **incus bridged network** IP labelled as `incusbr0`.
- `K3S_KUBECONFIG_MODE="644"` gives `kubectl` admin priviliges; not having to type _sudo kubectl_ all the time to manage the K3s cluster.
- `bind-address` specifically attaches the **incusbr0** IP to the control plane; instead of letting my actual PC IP address from the router get attached to the control plane, making it impossible for the incus node to talk to the control plane and vice versa.
- `advertise-address` hands the incus node the **incusbr0** IP to communicate to the control plane.
- `node-ip` is for kubelet and k8s to know which network to look at; points to **incusbr0** network.
- `--node-taint node-role.kubernetes.io/control-plane=true:NoSchedule` makes my arch linux (control plane) not accept any pods/deployments; it's strictly a control plane. All deployments should be assigned to the incus node. It only accepts essential control plane addons, like CoreDNS/network pods.

Confirm `K3s server` installation was successful:

```bash
kubectl get nodes -o wide
```

Confirm also that the taint was applied successfully:

```bash
kubectl describe node | grep -i taints
```

- In **kubectl get nodes -o wide** command output; the **ROLES** section should only have **control-plane**.

#### K3s Agent Setup (Node)

1. First, get the `K3s token` to be used to authenticate the K3s agent to the K3s server. Run this command in the K3s Server/Control Plane and copy the output:

   ```bash
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

- You'll paste this in the `K3S_TOKEN=` environment variable in the joining to the cluster step.

2. Fetch the K3s server IP. In my case, it's the `incusbr0` private bridged network I fetched earlier and assigned the **INCUS_IP** environment variable.

3. Setup the incus VM as a `K3s agent` (k8s node) by running this command on it make it join the K3s cluster:

   ```bash
   incus exec node-vm -- curl -sfL https://get.k3s.io | K3S_URL=https://k3s_server_ip:6443 K3S_TOKEN=<k3s_node_token> sh -
   ```

4. Verify your complete K3s cluster:

   ```bash
   kubectl get nodes -o wide
   ```
