#!/usr/bin/bash

msg_info "Setting up pulseaudio"
sound_card=""
for card_num in $(aplay -L | grep -oE '(surround[0-9]+|front|hdmi|hw|dmix|audio|usbstream|sysdefault|iec958|plughw):CARD=[^ ]*')
do
    if speaker-test -D $card_num -c 2 -l 1 > /dev/null 2>&1; then
        sound_card=$card_num
        break
    fi
done

if [ -n "$sound_card" ]; then
    msg_info "Setting up pulseaudio for sound card $sound_card"
    echo "load-module module-alsa-sink device=$sound_card" >> /etc/pulse/default.pa
    /bin/mkdir -p /home/vdkuser/.config/autostart/ 
    cat << EOF | tee -a /home/vdkuser/.config/autostart/pulse.desktop
[Desktop Entry]
Type=Application
Name=pulseaudio
Exec=/usr/bin/pulseaudio
StartupNotify=false
Terminal=false
EOF
    msg_ok "Pulseaudio configured for sound card $sound_card"
else
    msg_error "Failed to detect a functional sound card. Pulseaudio configuration not set."
fi
msg_ok "Pulseaudio configured"