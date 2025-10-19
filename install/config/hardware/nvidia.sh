# ==============================================================================
# Hyprland NVIDIA Setup Script for Arch Linux
# ==============================================================================
# This script automates the installation and configuration of NVIDIA drivers
# for use with Hyprland on Arch Linux, following the official Hyprland wiki.
#
# Behavior change: Always install proprietary precompiled NVIDIA drivers
# when an NVIDIA GPU is detected (no DKMS). Uses `nvidia` for the default
# kernel and `nvidia-lts`, `nvidia-zen`, or `nvidia-hardened` for variants
# when available. Multilib is enabled automatically.
#
# Author: https://github.com/Kn0ax
# ==============================================================================

# --- GPU Detection ---
if [ -n "$(lspci | grep -i 'nvidia')" ]; then
  echo "NVIDIA GPU detected. Forcing precompiled driver installation."

  # Decide kernel type for precompiled package suffixing
  KERNEL_TYPE="linux" # default
  if pacman -Q linux-zen &>/dev/null; then
    KERNEL_TYPE="linux-zen"
  elif pacman -Q linux-lts &>/dev/null; then
    KERNEL_TYPE="linux-lts"
  elif pacman -Q linux-hardened &>/dev/null; then
    KERNEL_TYPE="linux-hardened"
  fi

  # Always use proprietary precompiled package base
  NVIDIA_PRECOMPILED_BASE="nvidia"

  # Compose precompiled package name (e.g., nvidia, nvidia-lts, nvidia-zen)
  NVIDIA_PRECOMPILED_PACKAGE="$NVIDIA_PRECOMPILED_BASE"
  if [ "$KERNEL_TYPE" != "linux" ]; then
    NVIDIA_PRECOMPILED_PACKAGE="${NVIDIA_PRECOMPILED_BASE}-${KERNEL_TYPE#linux-}"
  fi

  # Ensure multilib is enabled for lib32-nvidia-utils
  if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\s*\[multilib\]/,/^#\s*Include/ s/^#\s*//' /etc/pacman.conf
  fi

  # Refresh package databases and system before driver install
  sudo pacman -Syu --noconfirm

  # If chosen package is not available for this kernel variant,
  # fall back to base proprietary precompiled package.
  if ! pacman -Si "$NVIDIA_PRECOMPILED_PACKAGE" &>/dev/null; then
    FALLBACK_PACKAGE="nvidia"
    if [ "$KERNEL_TYPE" != "linux" ]; then
      FALLBACK_PACKAGE="nvidia-${KERNEL_TYPE#linux-}"
    fi
    echo "Selected package '$NVIDIA_PRECOMPILED_PACKAGE' not found. Falling back to '$FALLBACK_PACKAGE'."
    NVIDIA_PRECOMPILED_PACKAGE="$FALLBACK_PACKAGE"
  else
    echo "Using precompiled driver package: $NVIDIA_PRECOMPILED_PACKAGE"
  fi

  # Install precompiled packages (no headers/DKMS required)
  PACKAGES_TO_INSTALL=(
    "$NVIDIA_PRECOMPILED_PACKAGE"
    "nvidia-utils"
    "lib32-nvidia-utils"
    "egl-wayland"
    "libva-nvidia-driver" # For VA-API hardware acceleration
    "qt5-wayland"
    "qt6-wayland"
  )

  sudo pacman -S --needed --noconfirm "${PACKAGES_TO_INSTALL[@]}"

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
