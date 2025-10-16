#!/bin/bash

# Enable and start input-remapper if installed
if systemctl list-unit-files | grep -q '^input-remapper\.service'; then
  sudo systemctl enable --now input-remapper.service || true
fi

# Default to never sleeping/locking/DPMS on idle (can be toggled via menu)
mkdir -p "$HOME/.local/state/omarchy/toggles"
touch "$HOME/.local/state/omarchy/toggles/idle-disabled"
