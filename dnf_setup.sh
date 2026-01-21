#!/bin/bash

# Get username from parameter
if [ -z "$1" ]; then
  echo "Error: Username not provided"
  echo "Usage: ./dnf_setup.sh <username>"
  exit 1
fi

username="$1"
user_home="/home/$username"

echo "Updating dnf..."
sudo dnf update -y && sudo dnf upgrade -y

echo "Installing dnf packages..."
sudo dnf install git curl vim neovim nodejs npm btop fzf gh nano luarocks sqlite-devel -y
sudo dnf group install development-tools -y

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing LazyVim..."
if [ -d "$user_home/.config/nvim" ]; then
  echo "Neovim config already exists, backing up..."
  mv "$user_home/.config/nvim" "$user_home/.config/nvim.bak.$(date +%s)"
fi
sudo -u "$username" git clone https://github.com/LazyVim/starter "$user_home/.config/nvim"
rm -rf "$user_home/.config/nvim/.git"
sudo chown -R "$username:$username" "$user_home/.config/nvim"

echo "Dnf setup completed successfully"
