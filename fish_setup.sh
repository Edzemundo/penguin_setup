#!/bin/bash

FISH_PATH="/usr/bin/fish"

if command -v apt &>/dev/null; then
  echo "Installing and configuring fish"
  sudo apt install fish -y

elif command -v dnf &>/dev/null; then
  echo "Installing and configuring fish"
  sudo dnf install fish -y

elif command -v pacman &>/dev/null; then
  echo "Installing and configuring fish"
  sudo pacman -Sy fish --noconfirm

else
  echo "Error: No supported package manager found"
  exit 1
fi

# Register fish shell
echo "Registering fish shell"
if ! grep -q "^${FISH_PATH}$" /etc/shells; then
  echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
fi

# Change default shell
echo "Changing default shell to fish"
chsh -s "$FISH_PATH"
echo "Fish installed successfully"

# Install fisher and fisher plugins
echo "Installing fisher and plugins"
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
fisher install PatrickF1/fzf.fish
