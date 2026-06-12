# Kubernetes Homelab

# VM Setup using `LXD | LXC`

1. Create and start **node1** VM.

   ```bash
   lxc launch ubuntu:26.04 node1 --vm < lxd/vm.yaml
   ```

2. Repeating same step for **node2**

   ```bash
   lxc launch ubuntu:26.04 node2 --vm < lxd/vm.yaml
   ```

Wait for the VM to successfully boot up and get assigned an IPv4 Address, before using it.

```bash
watch -n 1 lxc list
```
