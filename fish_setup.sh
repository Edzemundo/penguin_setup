#!/bin/bash

FISH_PATH="/usr/bin/fish"
FISH_PATH_2="/usr/sbin/fish"

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

if ! grep -q "^${FISH_PATH_2}$" /etc/shells; then
  echo "$FISH_PATH_2" | sudo tee -a /etc/shells > /dev/null
fi

echo "Fish installed successfully"
