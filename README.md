# Kubernetes Homelab

# Setup (Arch Linux)

Similar setup could be achieved on other distros. For Ubuntu, setup using `LXD`.

Install `incus`

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
