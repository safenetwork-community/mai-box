#!/usr/bin/env bash

. /tmp/files/vars.sh

NAME_SH=setup.sh

CONFIG_SCRIPT_SHORT=`basename "$CONFIG_SCRIPT"`
tee "${ROOT_DIR}${CONFIG_SCRIPT}" &>/dev/null << EOF
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring hostname, timezone, and keymap.."
  echo '${FQDN}' > /etc/hostname
  /usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
  echo 'KEYMAP=${KEYMAP}' > /etc/vconsole.conf
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring locale.."
  /usr/bin/sed -i 's/#${LANGUAGE}/${LANGUAGE}/' /etc/locale.gen
  /usr/bin/locale-gen
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Creating initramfs.."
  /usr/bin/mkinitcpio -p linux
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Setting root pasword.."
  /usr/bin/usermod --password ${PASSWORD} root
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring network.."
  # Disable systemd Predictable Network Interface Names and revert to traditional interface names
  # https://wiki.archlinux.org/index.php/Network_configuration#Revert_to_traditional_interface_names
  /usr/bin/ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
  /usr/bin/systemctl enable dhcpcd@eth0.service
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring sshd.."
  /usr/bin/sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
  /usr/bin/systemctl enable sshd.service
  # Workaround for https://bugs.archlinux.org/task/58355 which prevents sshd to accept connections after reboot
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Adding workaround for sshd connection issue after reboot.."
  /usr/bin/pacman -S --noconfirm rng-tools
  /usr/bin/systemctl enable rngd
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Enable time synching.."
  /usr/bin/pacman -S --noconfirm ntp
  /usr/bin/systemctl enable ntpd 
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Installing ${ISCR} non-AUR dependencies.."
  /usr/bin/pacman -S --noconfirm base-devel
  /usr/bin/pacman -S --noconfirm wget git parted 
  /usr/bin/pacman -S --noconfirm dialog dosfstools f2fs-tools polkit qemu-user-static-binfmt 
  # Vagrant user apparently created through pacstrap for Arch Linux.
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Modifying vagrant user.."
  /usr/bin/useradd --password ${TEMP_PASSWORD} --comment 'Vagrant User' -d /home/${USER} --user-group ${GROUP}
  /usr/bin/echo -e "${PASSWORD}\n${PASSWORD}" | /usr/bin/passwd ${USER}
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Configuring sudo.."
  echo "Defaults env_keep += \"SSH_AUTH_SOCK\"" | tee /etc/sudoers.d/10_${USER}
  echo "${USER} ALL=(ALL) NOPASSWD: ALL" | tee -a /etc/sudoers.d/10_${USER}
  /usr/bin/chmod 0440 /etc/sudoers.d/10_${USER}
  echo ">>>> ${CONFIG_SCRIPT_SHORT}: Cleaning up.."
  /usr/bin/pacman -Rcns --noconfirm gptfdisk
EOF

echo ">>>> ${NAME_SH}: Entering chroot and configuring system.."
/usr/bin/arch-chroot ${ROOT_DIR} ${CONFIG_SCRIPT}
rm "${ROOT_DIR}${CONFIG_SCRIPT}"

echo ">>>> ${NAME_SH}: Creating ssh access for ${USER}.."
/usr/bin/install --directory --owner=${USER} --group=${GROUP} --mode=0700 ${ROOT_DIR}${SSH_DIR}
/usr/bin/install --owner=${USER} --group=${GROUP} --mode=0600 ${A_KEYS_PATH} ${ROOT_DIR}${SSH_DIR}

# http://comments.gmane.org/gmane.linux.arch.general/48739
echo ">>>> ${NAME_SH}: Adding workaround for shutdown race condition.."
/usr/bin/install --mode=0644 ${FILES_DIR}/poweroff.timer "${ROOT_DIR}/etc/systemd/system/poweroff.timer"

# /usr/bin/ls -lha ${ROOT_DIR}/boot
# /usr/bin/ls -lha ${BOOT_DIR}
# /usr/bin/ls -lha ${BOOT_DIR}/EFI
# /usr/bin/cat ${ROOT_DIR}/etc/fstab
# /usr/bin/cat ${ROOT_DIR}/boot/grub/grub.cfg

echo ">>>> ${NAME_SH}: Completing installation.."
/usr/bin/umount ${BOOT_DIR}
/usr/bin/umount ${ROOT_DIR}
/usr/bin/rm -rf ${SSH_DIR}

# Turning network interfaces down to make sure SSH session was dropped on host.
# More info at: https://www.packer.io/docs/provisioners/shell.html#handling-reboots
echo '==> Turning down network interfaces and rebooting'
for i in $(/usr/bin/ip -o link show | /usr/bin/awk -F': ' '{print $2}'); do /usr/bin/ip link set ${i} down; done
/usr/bin/systemctl reboot
echo ">>>> ${NAME_SH}: Installation complete!"
