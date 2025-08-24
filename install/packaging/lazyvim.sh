#!/bin/bash

if [[ ! -d "$HOME/.config/nvim" ]]; then
  cp -R ~/.local/share/omarchy/config/nvim/* ~/.config/nvim/
  rm -rf ~/.config/nvim/.git
fi
