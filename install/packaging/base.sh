#!/bin/bash

# Install all base packages with optional fork overlays

BASE_LIST="$OMARCHY_INSTALL/omarchy-base.packages"
REMOVE_LIST="$OMARCHY_INSTALL/fork/remove.packages"
ADD_LIST="$OMARCHY_INSTALL/fork/add.packages"

# Read base list
mapfile -t base_packages < <(grep -v '^#' "$BASE_LIST" | grep -v '^$')

# Apply removal overlay if present
if [[ -f "$REMOVE_LIST" ]]; then
  mapfile -t remove_packages < <(grep -v '^#' "$REMOVE_LIST" | grep -v '^$')
else
  remove_packages=()
fi

# Filter out removed packages
filtered_packages=()
for pkg in "${base_packages[@]}"; do
  skip=false
  for r in "${remove_packages[@]}"; do
    if [[ "$pkg" == "$r" ]]; then
      skip=true
      break
    fi
  done
  [[ "$skip" == true ]] || filtered_packages+=("$pkg")
done

# Apply add overlay if present
if [[ -f "$ADD_LIST" ]]; then
  mapfile -t add_packages < <(grep -v '^#' "$ADD_LIST" | grep -v '^$')
  filtered_packages+=("${add_packages[@]}")
fi

# Dedupe while preserving order
declare -A seen
packages=()
for pkg in "${filtered_packages[@]}"; do
  if [[ -n "$pkg" && -z "${seen[$pkg]}" ]]; then
    packages+=("$pkg")
    seen[$pkg]=1
  fi
done

sudo pacman -S --noconfirm --needed "${packages[@]}"
