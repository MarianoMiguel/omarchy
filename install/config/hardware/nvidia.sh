#!/bin/bash
set -euo pipefail

log() { printf "\033[1;36m[omarchy-nvidia]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[omarchy-nvidia]\033[0m %s\n" "$*" >&2; }

is_installed() { pacman -Q "$1" &>/dev/null; }
has_pkg() { pacman -Si "$1" &>/dev/null; }

# Return first matching installed official kernel name or empty
detect_official_kernel() {
  for k in linux linux-zen linux-lts linux-hardened; do
    if is_installed "$k"; then
      echo "$k"
      return 0
    fi
  done
  echo ""
  return 1
}

kernel_headers_pkg_for() {
  case "$1" in
    linux) echo "linux-headers" ;;
    linux-zen) echo "linux-zen-headers" ;;
    linux-lts) echo "linux-lts-headers" ;;
    linux-hardened) echo "linux-hardened-headers" ;;
    *) echo "linux-headers" ;; # default / custom
  esac
}

gpu_is_nvidia() {
  lspci | grep -qi 'nvidia'
}

gpu_is_turing_ampere_ada_or_newer() {
  # Matches GTX 16xx, RTX 20xx–90xx; broad but effective before drivers are up
  lspci | grep -i 'nvidia' | grep -Eq 'RTX [2-9][0-9]|GTX 16'
}

enable_multilib() {
  if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    log "Enabling multilib…"
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  fi
}

ensure_headers_match() {
  local kname="$1"
  local khdr
  khdr="$(kernel_headers_pkg_for "$kname")"
  if ! is_installed "$khdr"; then
    log "Installing kernel headers: $khdr"
    sudo pacman -S --needed --noconfirm "$khdr"
  fi

  # best-effort sanity check
  local kv="$(pacman -Q "$kname" | awk '{print $2}')"
  local hv="$(pacman -Q "$khdr" | awk '{print $2}')"
  if [[ "${kv%%-*}" != "${hv%%-*}" ]]; then
    log "Note: $kname ($kv) and $khdr ($hv) differ. A full system upgrade may be required for DKMS."
  fi
}

install_vaapi_wayland_bits() {
  sudo pacman -S --needed --noconfirm \
    egl-wayland libva-nvidia-driver nvidia-utils lib32-nvidia-utils \
    qt5-wayland qt6-wayland
}

set_early_kms_and_initramfs() {
  log "Configuring early KMS + initramfs…"
  echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

  local conf="/etc/mkinitcpio.conf"
  local mods="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

  sudo cp "$conf" "${conf}.backup"

  # Remove duplicates then prepend NVIDIA modules
  sudo sed -i -E 's/\<(nvidia_drm|nvidia_uvm|nvidia_modeset|nvidia)\>//g' "$conf"
  sudo sed -i -E "s/^(MODULES=\()/\1${mods} /" "$conf"
  sudo sed -i -E 's/  +/ /g' "$conf"

  sudo mkinitcpio -P
}

set_hyprland_env() {
  local hc="$HOME/.config/hypr/hyprland.conf"
  mkdir -p "$(dirname "$hc")"
  if ! grep -q "__GLX_VENDOR_LIBRARY_NAME" "$hc" 2>/dev/null; then
    log "Appending NVIDIA env vars to hyprland.conf…"
    cat >>"$hc" <<'EOF'

# NVIDIA environment variables (Wayland)
env = NVD_BACKEND,direct
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
# Occasionally useful if you see cursor glitches:
# env = WLR_NO_HARDWARE_CURSORS,1
EOF
  fi
}

dkms_build_ok() {
  # Return 0 if any nvidia dkms build is installed for current kernel
  local uname_r
  uname_r="$(uname -r)"
  dkms status 2>/dev/null | grep -qi "nvidia/.*,$uname_r,.*installed"
}

install_nvidia_for_hyprland() {
  if ! gpu_is_nvidia; then
    log "No NVIDIA GPU detected. Skipping."
    return 0
  fi

  enable_multilib

  local official_kernel
  official_kernel="$(detect_official_kernel)"

  # Decide preferred track (prebuilt vs dkms)
  local prefer_open_prebuilt=false
  local prefer_legacy_prebuilt=false
  if [[ -n "$official_kernel" ]]; then
    if gpu_is_turing_ampere_ada_or_newer; then
      prefer_open_prebuilt=true   # RTX 3080 path
    else
      prefer_legacy_prebuilt=true
    fi
  fi

  # Ensure headers for the main kernel (both prebuilt and dkms paths benefit)
  local hdr_pkg="linux-headers"
  if [[ -n "$official_kernel" ]]; then
    hdr_pkg="$(kernel_headers_pkg_for "$official_kernel")"
  fi
  ensure_headers_match "${official_kernel:-linux}"

  # Choose package set
  local driver_pkg=""
  local dkms_pkg=""
  if "$prefer_open_prebuilt" && has_pkg nvidia-open; then
    driver_pkg="nvidia-open"
  elif "$prefer_legacy_prebuilt" && has_pkg nvidia; then
    driver_pkg="nvidia"
  else
    # Fallback to DKMS flavor
    if gpu_is_turing_ampere_ada_or_newer; then
      dkms_pkg="nvidia-open-dkms"
    else
      dkms_pkg="nvidia-dkms"
    fi
  fi

  sudo pacman -Syy

  if [[ -n "$driver_pkg" ]]; then
    log "Installing prebuilt driver: $driver_pkg"
    sudo pacman -S --needed --noconfirm "$hdr_pkg" "$driver_pkg"
  else
    log "Installing DKMS driver: $dkms_pkg"
    # DKMS builds need toolchain
    sudo pacman -S --needed --noconfirm base-devel dkms "$hdr_pkg" "$dkms_pkg"
    # Try to make sure modules are built for current kernel
    sudo dkms autoinstall || true

    if ! dkms_build_ok; then
      err "DKMS build failed. Attempting recovery by switching to prebuilt driver…"
      if [[ -n "$official_kernel" ]] && has_pkg nvidia-open; then
        sudo pacman -Rns --noconfirm "$dkms_pkg" || true
        sudo pacman -S --needed --noconfirm "nvidia-open"
        driver_pkg="nvidia-open"
      elif [[ -n "$official_kernel" ]] && has_pkg nvidia; then
        sudo pacman -Rns --noconfirm "$dkms_pkg" || true
        sudo pacman -S --needed --noconfirm "nvidia"
        driver_pkg="nvidia"
      else
        err "No prebuilt driver available for your kernel. You may need to align kernel & headers (pacman -Syu) or use an official Arch kernel."
      fi
    fi
  fi

  install_vaapi_wayland_bits
  set_early_kms_and_initramfs
  set_hyprland_env

  log "NVIDIA setup complete. Consider rebooting to load modules cleanly."
}

# --- Entry point ---
install_nvidia_for_hyprland
