#!/bin/bash

# ==============================================================================
# Hyprland NVIDIA Setup Script for Arch Linux
# ==============================================================================
# This script automates the installation and configuration of NVIDIA drivers
# for use with Hyprland on Arch Linux, following the official Hyprland wiki.
#
# Author: https://github.com/Kn0ax
#
# ==============================================================================

# --- GPU Detection ---
if [ -n "$(lspci | grep -i 'nvidia')" ]; then
  # --- Driver Selection ---
  # Turing (16xx, 20xx), Ampere (30xx), Ada (40xx), and newer recommend the open-source kernel modules
  if echo "$(lspci | grep -i 'nvidia')" | grep -q -E "RTX [2-9][0-9]|GTX 16"; then
    NVIDIA_DRIVER_PACKAGE="nvidia-open-dkms"
  else
    NVIDIA_DRIVER_PACKAGE="nvidia-dkms"
  fi

  # Check which kernel is installed and set appropriate headers package
  KERNEL_HEADERS="linux-headers" # Default
  KERNEL_TYPE="linux"
  
  if pacman -Q linux-zen &>/dev/null; then
    KERNEL_HEADERS="linux-zen-headers"
    KERNEL_TYPE="linux-zen"
  elif pacman -Q linux-lts &>/dev/null; then
    KERNEL_HEADERS="linux-lts-headers"
    KERNEL_TYPE="linux-lts"
  elif pacman -Q linux-hardened &>/dev/null; then
    KERNEL_HEADERS="linux-hardened-headers"
    KERNEL_TYPE="linux-hardened"
  fi

  # Determine pre-compiled fallback package
  if echo "$(lspci | grep -i 'nvidia')" | grep -q -E "RTX [2-9][0-9]|GTX 16"; then
    NVIDIA_FALLBACK_PACKAGE="nvidia-open"
  else
    NVIDIA_FALLBACK_PACKAGE="nvidia"
  fi
  
  if [ "$KERNEL_TYPE" != "linux" ]; then
    NVIDIA_FALLBACK_PACKAGE="${NVIDIA_FALLBACK_PACKAGE}-${KERNEL_TYPE#linux-}"
  fi

  # Enable multilib repository for 32-bit libraries
  if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\s*\[multilib\]/,/^#\s*Include/ s/^#\s*//' /etc/pacman.conf
  fi

  # force package database refresh
  sudo pacman -Syu --noconfirm

  install_nvidia_with_fallback() {
    local DKMS_PACKAGES=(
      "${KERNEL_HEADERS}"
      "${NVIDIA_DRIVER_PACKAGE}"
      "nvidia-utils"
      "lib32-nvidia-utils"
      "egl-wayland"
      "libva-nvidia-driver" # For VA-API hardware acceleration
      "qt5-wayland"
      "qt6-wayland"
    )
    
    local FALLBACK_PACKAGES=(
      "${NVIDIA_FALLBACK_PACKAGE}"
      "nvidia-utils"
      "lib32-nvidia-utils"
      "egl-wayland"
      "libva-nvidia-driver" # For VA-API hardware acceleration
      "qt5-wayland"
      "qt6-wayland"
    )
    
    echo "Attempting to install NVIDIA drivers with DKMS support..."
    echo "Using DKMS package: ${NVIDIA_DRIVER_PACKAGE}"
    
    if sudo pacman -S --needed --noconfirm "${DKMS_PACKAGES[@]}" 2>/dev/null; then
      echo "Successfully installed NVIDIA drivers with DKMS support."
      return 0
    else
      echo "DKMS installation failed. Falling back to pre-compiled NVIDIA packages..."
      echo "Using fallback package: ${NVIDIA_FALLBACK_PACKAGE}"
      
      sudo pacman -Rns --noconfirm "${NVIDIA_DRIVER_PACKAGE}" "${KERNEL_HEADERS}" 2>/dev/null || true
      
      if sudo pacman -S --needed --noconfirm "${FALLBACK_PACKAGES[@]}"; then
        echo "Successfully installed pre-compiled NVIDIA drivers."
        echo "NOTE: These drivers are kernel-specific and will need to be updated with kernel changes."
        return 0
      else
        echo "ERROR: Both DKMS and pre-compiled NVIDIA driver installation failed."
        echo "You may need to manually install appropriate NVIDIA drivers for your system."
        return 1
      fi
    fi
  }

  install_nvidia_with_fallback

  # Configure modprobe for early KMS
  echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

  # Configure mkinitcpio for early loading
  MKINITCPIO_CONF="/etc/mkinitcpio.conf"

  # Define modules
  NVIDIA_MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

  # Create backup
  sudo cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.backup"

  # Remove any old nvidia modules to prevent duplicates
  sudo sed -i -E 's/ nvidia_drm//g; s/ nvidia_uvm//g; s/ nvidia_modeset//g; s/ nvidia//g;' "$MKINITCPIO_CONF"
  # Add the new modules at the start of the MODULES array
  sudo sed -i -E "s/^(MODULES=\\()/\\1${NVIDIA_MODULES} /" "$MKINITCPIO_CONF"
  # Clean up potential double spaces
  sudo sed -i -E 's/  +/ /g' "$MKINITCPIO_CONF"

  sudo mkinitcpio -P

  # Add NVIDIA environment variables to hyprland.conf
  HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"
  if [ -f "$HYPRLAND_CONF" ]; then
    cat >>"$HYPRLAND_CONF" <<'EOF'

# NVIDIA environment variables
env = NVD_BACKEND,direct
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
EOF
  fi
fi
