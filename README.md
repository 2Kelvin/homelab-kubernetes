# Kubernetes Homelab

# Setup (on Arch Linux)

Install `incus`

```bash
sudo pacman -Syu incus
```

Setting up incus and starting the its service

```bash
# give user root privileges to run incus automatically
# then reload shell instantly
sudo usermod -aG incus-admin $USER
newgrp incus-admin

# running the service/socket
sudo systemctl enable --now incus.socket
sudo systemctl enable --now incus.service
incus admin init --minimal
```
