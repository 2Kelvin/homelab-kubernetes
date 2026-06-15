# Kubernetes Homelab

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
  sudo systemctl restart incus-daemon.service
  ```

### Create Kubernetes Worker Nodes (Incus System Containers)

Creating 2 worker nodes for the Kubernetes Cluster. I'll use `incus system containers` rather than VMs since they are more resource efficient; they share my Linux Kernel.

```bash
incus launch images:ubuntu/26.04/cloud node1 < sys-container.yaml
incus launch images:ubuntu/26.04/cloud node2 < sys-container.yaml
```
