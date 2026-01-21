#!/bin/bash

# Get username from parameter
if [ -z "$1" ]; then
  echo "Error: Username not provided"
  echo "Usage: ./pacman_setup.sh <username>"
  exit 1
fi

username="$1"
user_home="/home/$username"

echo "Updating pacman..."
sudo pacman -Syu --noconfirm

echo "Installing pacman packages..."
sudo pacman -S --noconfirm git curl base-devel sqlite github-cli nano btop fzf npm luarocks neovim nodejs ripgrep fd

echo "Installing yay (AUR helper) if not present..."
if ! command -v yay &>/dev/null; then
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay
  makepkg -si --noconfirm
  cd -
  rm -rf /tmp/yay
fi

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing LazyVim..."
if [ -d "$user_home/.config/nvim" ]; then
  echo "Backing up existing nvim config..."
  mv "$user_home/.config/nvim" "$user_home/.config/nvim.bak.$(date +%s)"
fi
sudo -u "$username" git clone https://github.com/LazyVim/starter "$user_home/.config/nvim"
rm -rf "$user_home/.config/nvim/.git"
chown -R "$username:$username" "$user_home/.config/nvim"

echo "Pacman setup completed successfully"
