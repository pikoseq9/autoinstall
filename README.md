# Ubuntu PXE Server (Ubuntu 24.04)

Ten projekt pozwala zainstalować system Ubuntu 24.04 na innych komputerach w sieci LAN za pomocą PXE boot.

## Wymagania
- Serwer z Ubuntu 22.04/24.04
- Karta sieciowa ustawiona jako DHCP serwer (np. osobna sieć LAN)
- Komputery-klienci, które wspierają bootowanie z sieci (PXE)

## Instalacja
```bash
git https://github.com/pikoseq9/autoinstall.git pxe-server
cd pxe-server
chmod +x install.sh
sudo ./install.sh