#!/usr/bin/env bash

YW=`echo "\033[33m"`
RD=`echo "\033[01;31m"`
BL=`echo "\033[36m"`
GN=`echo "\033[1;92m"`
CL=`echo "\033[m"`
RETRY_NUM=10
RETRY_EVERY=3
NUM=$RETRY_NUM
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
BFR="\\r\\033[K"
HOLD="-"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR

function error_exit() {
  trap - ERR
  local reason="Unknown failure occurred."
  local msg="${1:-$reason}"
  local flag="${RD}‼ ERROR ${CL}$EXIT@$LINE"
  echo -e "$flag $msg" 1>&2
  exit $EXIT
}

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

msg_info "Setting up Container OS "
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null
# TODO Rebuild network detection
#while [ "$(hostname -I)" = "" ]; do
#  1>&2 echo -en "${CROSS}${RD} No Network! "
#  sleep $RETRY_EVERY
#  ((NUM--))
#  if [ $NUM -eq 0 ]
#  then
#    1>&2 echo -e "${CROSS}${RD} No Network After $RETRY_NUM Tries${CL}"    
#    exit 1
#  fi
#done
msg_ok "Set up Container OS"
#msg_ok "Network Connected: ${BL}$(hostname -I)"

#if nc -zw1 8.8.8.8 443; then  msg_ok "Internet Connected"; else  msg_error "Internet NOT Connected"; exit 1; fi;
#RESOLVEDIP=$(nslookup "github.com" | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
#if [[ -z "$RESOLVEDIP" ]]; then msg_error "DNS Lookup Failure";  else msg_ok "DNS Resolved github.com to $RESOLVEDIP";  fi;

msg_info "Updating Container OS"
pacman-key --init && pacman-key --populate archlinux &>/dev/null
yes | pacman -Sy archlinux-keyring && yes | pacman -Suy &>/dev/null
msg_ok "Updated Container OS"

msg_info "Updating multilib repo"
cat << EOF | tee -a /etc/pacman.d/mirrorlist
[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
msg_info "Updated multilib repo"

msg_info "Installing Dependencies"
yes | pacman -Syu &>/dev/null
yes | pacman -S git vim nvtop htop &>/dev/null
msg_ok "Installed Dependencies"

msg_info "Setting Up Hardware Acceleration"  
yes | sudo pacman -S xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau libva-utils &>/dev/null
msg_ok "Set Up Hardware Acceleration"  

msg_info "Setting Up vdkuser"
echo "vdkuser ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers &>/dev/null
useradd -d /home/vdkuser -m vdkuser &>/dev/null
gpasswd -a vdkuser audio &>/dev/null
gpasswd -a vdkuser video &>/dev/null
gpasswd -a vdkuser render &>/dev/null
groupadd -r autologin &>/dev/null
gpasswd -a vdkuser autologin &>/dev/null
gpasswd -a vdkuser input &>/dev/null #to enable direct access to devices
msg_ok "Set Up vdkuser user"

msg_info "Installing lightdm"
yes | pacman -S lightdm &>/dev/null
echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager
msg_ok "Installed lightdm"
# add greetter login manager lightdm-gtk-greeter

msg_info "Installing lightdm"
yes | pacman -S xfce4 xfce4-terminal \
      xfce4-terminal \
      firefox &>/dev/null
msg_ok "Installed lightdm"


msg_info "Updating xsession"
cat <<EOF >/usr/share/xsessions/vdkuser-alsa.desktop
[Desktop Entry]
Name=vdkuser-alsa
Comment=This session will start xfce with alsa support
Exec=env AE_SINK=ALSA vdkuser-standalone
TryExec=env AE_SINK=ALSA vdkuser-standalone
Type=Application
EOF
msg_ok "Updated xsession"

msg_info "Setting up autologin"
cat <<EOF >/etc/lightdm/lightdm.conf.d/autologin-vdkuser.conf
[Seat:*]
autologin-user=vdkuser
autologin-session=vdkuser-alsa
EOF
msg_ok "Set up autologin"

msg_info "Setting up device detection for xorg"
yes | pacman -S  xf86-input-evdev  &>/dev/null
#following script needs to be executed before Xorg starts to enumerate all input devices
/bin/mkdir -p /etc/X11/xorg.conf.d
cat >/usr/local/bin/preX-populate-input.sh  << __EOF__
#!/usr/bin/env bash

### Creates config file for X with all currently present input devices
#   after connecting new device restart X (systemctl restart lightdm)
######################################################################

cat >/etc/X11/xorg.conf.d/10-lxc-input.conf << _EOF_
Section "ServerFlags"
     Option "AutoAddDevices" "False"
EndSection
_EOF_

cd /dev/input
for input in event*
do
cat >> /etc/X11/xorg.conf.d/10-lxc-input.conf <<_EOF_
Section "InputDevice"
    Identifier "\$input"
    Option "Device" "/dev/input/\$input"
    Option "AutoServerLayout" "true"
    Driver "evdev"
EndSection
_EOF_
done
__EOF__
/bin/chmod +x /usr/local/bin/preX-populate-input.sh
/bin/mkdir -p /etc/systemd/system/lightdm.service.d
cat > /etc/systemd/system/lightdm.service.d/override.conf << __EOF__
[Service]
ExecStartPre=/bin/sh -c '/usr/local/bin/preX-populate-input.sh'
SupplementaryGroups=video render input audio tty
__EOF__
systemctl daemon-reload
msg_ok "Set up device detection for xorg"

PASS=$(grep -w "root" /etc/shadow | cut -b6);
  if [[ $PASS != $ ]]; then
msg_info "Customizing Container"
chmod -x /etc/update-motd.d/*
touch ~/.hushlogin
GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
mkdir -p $(dirname $GETTY_OVERRIDE)
cat << EOF > $GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
systemctl daemon-reload
systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
msg_ok "Customized Container"
  fi
  
msg_info "Cleaning up"
#clean archlinux
msg_ok "Cleaned"

msg_info "Starting X up"
systemctl start lightdm
ln -fs /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
msg_info "Started X"



