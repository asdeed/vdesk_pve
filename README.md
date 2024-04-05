# VDesk_pve

Scripts from quick setup GPU accelerated Linux Desktop with LXC on Proxmox (Arch Linux base). Only for AMD graphic card (currently tested on RX580).

based on these repo : 
- https://github.com/tteck/Proxmox
- https://github.com/mrrudy/proxmoxHelper


## TODO
- Add install scripts for Intel (iGPU) "Intel graphics" 
- Add install scripts for Nvidia


## Quick start

On proxmox shell:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/asdeed/vdesk_pve/main/lxc_set.sh)"
```

at the end of installation Arch container should be attached to TTY7 console.


### Troubleshoot: incorect path for graphic device

```bash
ls -la /dev/dri/by-path/
ls -la /sys/class/graphics/
```