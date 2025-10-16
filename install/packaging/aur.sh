#!/bin/bash

# Install AUR packages from fork overlay, if present and accessible

AUR_LIST="$OMARCHY_INSTALL/fork/add-aur.packages"

# Only proceed if yay is available and AUR is reachable
if command -v yay >/dev/null && omarchy-pkg-aur-accessible >/dev/null 2>&1; then
  if [[ -f "$AUR_LIST" ]]; then
    mapfile -t aur_packages < <(grep -v '^#' "$AUR_LIST" | grep -v '^$')
    if [[ ${#aur_packages[@]} -gt 0 ]]; then
      yay -S --noconfirm --needed "${aur_packages[@]}"
    fi
  fi
else
  echo "Skipping AUR packages: yay not found or AUR unreachable" >&2
fi
