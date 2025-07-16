#!/bin/bash
set -e

# Aktualizacja i instalacja potrzebnych pakietów
sudo apt update
sudo apt-get install -qy dnsmasq pxelinux syslinux-common wget curl

# Tworzenie struktur katalogów
sudo mkdir -p /srv/tftp/pxelinux.cfg
sudo mkdir -p /srv/tftp/boot

# Kopiowanie plików PXE
sudo cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/menu.c32 /srv/tftp/

# Pobieranie kernela i initrd Ubuntu 24.04
wget -O /srv/tftp/boot/linux https://cdimage.ubuntu.com/ubuntu-server/daily/current/noble-live-server-amd64.kernel
wget -O /srv/tftp/boot/initrd https://cdimage.ubuntu.com/ubuntu-server/daily/current/noble-live-server-amd64.initrd

# Kopiowanie konfiguracji PXE
sudo cp -r pxelinux.cfg /srv/tftp/

# Kopiowanie preseed
sudo cp boot/ubuntu.seed /srv/tftp/boot/

# Konfiguracja dnsmasq (serwer DHCP + TFTP)
sudo tee /etc/dnsmasq.d/pxe.conf > /dev/null <<EOF
port=0
interface=enp0s3
bind-interfaces
dhcp-range=192.168.1.100,192.168.1.150,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/srv/tftp
EOF

# Restart dnsmasq
sudo systemctl restart dnsmasq
