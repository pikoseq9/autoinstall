#!/bin/bash

# Install needed libs
sudo apt update &> /dev/null
sudo apt-get install -y apache2 tftp-hpa isc-dhcp-server pxelinux syslinux-common curl &> /dev/null

# Configure tftp.conf 
sudo bash -c 'cat <<EOF >> /etc/apache2/conf-available/tftp.conf
<Directory /srv/tftp>
Options +FollowSymLinks +Indexes
Require all granted
</Directory>
Alias /tftp /srv/tftp
EOF'

# Turn on the Apache config file and reload 
sudo a2enconf tftp &> /dev/null
sudo systemctl reload apache2 &> /dev/null

# Create new dnsmasq.conf (test IP address, need to change)
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.old
sudo bash -c 'cat <<EOF >> /etc/dnsmasq.conf
interface=enp0s8
bind-interfaces
domain=autoinstall.local

dhcp-range=192.168.0.10,192.168.0.100,12h
dhcp-option=option:dns-server,192.168.0.1

enable-tftp
tftp-root=/srv/tftp/
dhcp-boot=bootx64.efi

pxe-prompt="Press F8 for PXE Network boot.", 5
pxe-service=x86PC, "Install OS via PXE", bootx64.efi
EOF'

# Enable and restart needed services
sudo systemctl enable systemd-resolved --now
sudo systemctl restart systemd-resolved
sudo systemctl enable dnsmasq --now
sudo systemctl enable apache2 --now
sudo systemctl enable tftpd-hpa --now
sudo systemctl restart dnsmasq

# Download ubuntu iso file
sudo wget https://releases.ubuntu.com/24.04/ubuntu-24.04.2-desktop-amd64.iso -O /srv/tftp/ubuntu-desktop-24-04.iso

sudo mount /srv/tftp/ubuntu-desktop-24-04.iso /mnt/
sudo mkdir /srv/tftp/noble
sudo cp /mnt/casper/{vmlinuz,initrd} /srv/tftp/noble
sudo umount /mnt 

# Get needed boot files
cd /tmp/

sudo apt-get download shim.signed -y
sudo dpkg-deb -x shim-signed_*.deb shim
sudo cp shim/usr/lib/shim/shimx64.efi.signed.latest /srv/tftp/bootx64.efi

sudo apt-get download grub-efi-amd64-signed
dpkg-deb -x /tmp/grub-efi-amd64-signed*deb grub
sudo cp ./grub/usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed /srv/tftp/grubx64.efi

sudo apt-get download grub-common
sudo dpkg-deb -x grub-common*deb /grub-common
sudo cp /grub-common/usr/share/grub/unicode.pf2 /srv/tftp/unicode.pf2

sudo mkdir -p /srv/tftp/grub

# Add installer to grub.cfg
sudo bash -c 'cat <<EOF >> /srv/tftp/grub/grub.cfg
set default=autoinstall
set timeout=30
set timeout_style=menu

menuentry "22.04 desktop Installer - automated" --id=autoinstall {
    linux /noble/casper/vmlinuz ip=dhcp url=http://192.168.0.1/tftp/noble/ubuntu-desktop-24-04.iso autoinstall ds=nocloud-net\;s=http://192.168.0.1/tftp/noble root=/dev/ram0
    echo "Loading RAM"
    initrd /noble/initrd
}
EOF'

# Add pxelinux to also manage a BIOS boot
sudo cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
sudo mkdir -p /srv/tftp/pxelinux.cfg
sudo touch /srv/tftp/pxelinux.cfg/default
sudo bash -c 'cat <<EOF >> /srv/tftp/pxelinux.cfg/default
LABEL linux
LABEL install
  MENU LABEL Ubuntu 24.04 Autoinstall
  KERNEL /noble/vmlinuz
  APPEND initrd=/noble/initrd ip=dhcp url=http://192.168.0.1/tftp/noble/ubuntu-desktop-24-04.iso autoinstall ds=nocloud-net;s=http://192.168.0.1/tftp/noble/ root=/dev/ram0 quiet ---

EOF'

# Add meta-data file
sudo mv /srv/tftp/ubuntu-desktop-24-04.iso /srv/tftp/noble/
sudo touch /srv/tftp/noble/meta-data

sudo bash -c 'cat <<EOF >> /srv/tftp/noble/meta-data
#cloud-config
EOF'

# Add user-data file
sudo touch /srv/tftp/noble/user-data

sudo bash -c 'cat <<EOF >> /srv/tftp/noble/user-data
#cloud-config
autoinstall:
  version: 1
  interactive-sections:
    - identity
  identity:
    hostname: U-autoinstall
    username: BlueSparrow
    password: "$6$U2Na7Tzo85aA3l4q$AzIEoNtGESGvIVdqNKPNqsbr7Vkn.MpTLK6uEtamWVBUdyo2LxYQELYqUHYjtpTpWdDxRnLk9122Nms6Zm68T1"
  keyboard:
    layout: pl
    variant: nodeadkeys
  locale: pl_PL
  timezone: Europe/Warsaw
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true
  storage:
    grub:
      reorder_uefi: true
  user-data:
    disable_root: false
  apt:
    primary:
      - arches: [amd64]
        uri: http://archive.ubuntu.com/ubuntu
  packages:
    - openssh-server
    - net-tools
    - curl
    - wget
    - vim
  late-commands:
    echo "PXE instalacja zakończona"
EOF'

# Set permissions to tftp server files
sudo chown -R nobody:nogroup /srv/tftp
sudo chmod -R 755 /srv/tftp 