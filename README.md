# VDesk_pve

Scripts from quick setup GPU accelerated Linux Desktop with LXC on Proxmox (Arch Linux/Debian base). Only for AMD graphic card (currently tested on RX580).

based on these repo : 
- https://github.com/tteck/Proxmox
- https://github.com/mrrudy/proxmoxHelper


## TODO
- Add install scripts for Intel (iGPU) & Nvidia
- Add install scripts for Debian (Nvidia/intel/AMD)

## Quick start

On proxmox shell:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/asdeed/vdesk_pve/main/lxc_set.sh)"
```

at the end of installation your container should be attached to TTY7 console.

### Troubleshoot: incorect path for graphic device

```bash
ls -la /dev/dri/by-path/
ls -la /sys/class/graphics/
```

### Troubleshoot: incorect path for soud devices

```bash
ls -la /dev/snd/by-path/
# List all devices
aplay -L
# put devices on config file
echo "load-module module-alsa-sink device=hw:CARD=HDMI,DEV=8" >> /etc/pulse/default.pa 
echo "load-module module-alsa-sink device=plughw:CARD=HDMI,DEV=8" >> /etc/pulse/default.pa 
echo "load-module module-alsa-sink device=hdmi:CARD=HDMI,DEV=2" >> /etc/pulse/default.pa
echo "load-module module-alsa-sink device=dmix:CARD=HDMI,DEV=8" >> /etc/pulse/default.pa
pulseaudio
```
