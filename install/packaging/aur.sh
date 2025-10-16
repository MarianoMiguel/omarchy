#!/bin/bash

# Install AUR packages from fork overlay, if present

AUR_LIST="$OMARCHY_INSTALL/fork/add-aur.packages"

if [[ -f "$AUR_LIST" ]]; then
  mapfile -t aur_packages < <(grep -v '^#' "$AUR_LIST" | grep -v '^$')
  if [[ ${#aur_packages[@]} -gt 0 ]]; then
    yay -S --noconfirm --needed "${aur_packages[@]}"
  fi
fi

