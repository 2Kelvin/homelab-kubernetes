# Kubernetes Homelab

My Kubernetes homelab built using `Incus` and `K3s`. My cluster is a **2 node K3s cluster**; my Arch linux PC is the control plane while the incus Ubuntu VM is the worker node.

This homelab has been built on **Arch Linux**. However, a similar setup could be achieved on other distros. For Ubuntu, setup using the native `LXD` instead of `Incus`, they work the same.

## `Incus` Install, Setup & VM Creation

1.  Installing Incus from the system package manager:

    ```bash
    sudo pacman -Syu incus
    ```

2.  Setting up Incus and its service

    ```bash
    # giving the user root privileges to run incus automatically without sudo
    # then reloading the shell instantly
    sudo usermod -aG incus-admin $USER
    newgrp incus-admin

    # starting incus service/socket
    sudo systemctl enable --now incus.socket
    sudo systemctl enable --now incus.service

    # accept all the defaults when setting this up or use the incus-preseed.yaml file
    incus admin init
    ```

3.  Creating a Kubernetes Node (Incus VM)

    Here, I'm creating an Ubuntu VM with Incus to act as the worker node in the K3s Cluster.

    ```bash
    incus launch images:ubuntu/26.04/cloud node-vm < incus/vm.yaml
    ```

## `K3s` Install and Cluster Setup

It's important to **disable swap memory** when running a Kubernetes cluster, but since am using my personal PC, I chose not to disable Arch Linux's Zram Swap to avoid system performance hits.

### K3s Server Setup (Control Plane)

1. Installing `K3s server`, is as easy as running this:

   ```bash
   curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s - --node-taint node-role.kubernetes.io/control-plane=true:NoSchedule
   ```

   But due to my unique setup, this is what I used:

   I first fetched my Incus Bridged Network Default Gateway IP and assigned it to an environment variable for reuse. This is the IP that the Incus Ubuntu VM node will use to communicate to my arch control plane PC and vice versa.

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

   - `ip addr show incusbr0 | grep "inet " | awk '{print $2}' | cut -d/ -f1` fetches my **incus bridged network** IP labelled as `incusbr0`.
   - `K3S_KUBECONFIG_MODE="644"` gives `kubectl` admin priviliges; not having to type _sudo kubectl_ all the time to manage the K3s cluster.
   - `bind-address` specifically attaches the **incusbr0** IP to the control plane; instead of letting my actual PC IP address from the router get attached to the control plane, making it impossible for the Incus node to talk to the control plane and vice versa.
   - `advertise-address` hands the Incus node the **incusbr0** IP to communicate to the control plane.
   - `node-ip` is for kubelet and k8s to know which network to look at; points to **incusbr0** network.
   - `--node-taint node-role.kubernetes.io/control-plane=true:NoSchedule` makes my arch linux (control plane) not accept any pods/deployments; it's strictly a control plane. All deployments should be assigned to the Incus node. It only accepts essential control plane addons, like CoreDNS/network pods.

2. Confirming `K3s server` installation was successful:

   ```bash
   kubectl get nodes -o wide
   ```

3. Confirming that the taint was applied successfully:

   ```bash
   kubectl describe node | grep -i taints
   ```

   - In **kubectl get nodes -o wide** command output; the **ROLES** section should also only have **control-plane** to confirm the taint was successfully applied.

### K3s Agent Setup (Worker Node)

1. Fetching the `K3s token` to be used to authenticate the K3s agent to the K3s server. I ran this command in the K3s Server/Control Plane and copied the output:

   ```bash
   sudo cat /var/lib/rancher/k3s/server/node-token
   ```

2. Fetching the K3s server IP. In my case, it's the `incusbr0` private bridged network I fetched earlier and assigned the **INCUS_IP** environment variable.

3. Finally, setting up the Ubuntu Incus VM as a `K3s agent` (worker node) by running this command to make it join the K3s cluster:

   ```bash
   incus exec node-vm -- sh -c 'curl -sfL https://get.k3s.io | K3S_URL=https://k3s_server_ip:6443 K3S_TOKEN=<k3s_node_token> sh -'
   ```

4. Verifying the complete K3s cluster:

   ```bash
   kubectl get nodes -o wide
   ```

---

## K3s Cluster `Load Balancer` Setup (`Nginx`)

1. Creating the Load Balancer VM with the necessary compute resources and `Nginx` installed:

```bash
incus launch images:ubuntu/26.04/cloud load-balancer --vm < incus/k8s-loadbalancer-vm.yaml
```
