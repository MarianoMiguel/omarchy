#!/bin/bash

set -euo pipefail

echo -e "\e[32mConfiguring NetworkManager (iwd backend + systemd-resolved)\e[0m"

# Ensure NetworkManager is installed (will be via package overlays, but be safe)
if ! pacman -Q networkmanager &>/dev/null; then
  sudo pacman -S --noconfirm --needed networkmanager
fi

# Configure NetworkManager to use iwd as Wi‑Fi backend and systemd-resolved for DNS
sudo install -d -m 0755 /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF

sudo tee /etc/NetworkManager/conf.d/dns.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

# Use systemd-resolved stub resolver
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Make sure systemd-resolved is enabled and active
sudo systemctl enable --now systemd-resolved

# Prefer NetworkManager over systemd-networkd and wpa_supplicant
sudo systemctl disable --now systemd-networkd.service || true
sudo systemctl disable --now systemd-networkd.socket || true
sudo systemctl disable --now systemd-networkd-varlink.socket || true
sudo systemctl mask wpa_supplicant.service || true

# Keep iwd available (backend for NM)
sudo systemctl enable --now iwd.service || true

# Enable NetworkManager
sudo systemctl enable --now NetworkManager

echo -e "\e[32mNetworkManager configured.\e[0m"

