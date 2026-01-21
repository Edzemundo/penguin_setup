#!/bin/bash

# Get username from parameter
if [ -z "$1" ]; then
  echo "Error: Username not provided"
  echo "Usage: ./apt_setup.sh <username>"
  exit 1
fi

username="$1"
user_home="/home/$username"

echo "Updating apt..."
sudo apt update && sudo apt upgrade -y

echo "Installing apt packages..."
sudo apt install git curl build-essential libsqlite3-dev gh nano btop fzf npm luarocks neovim -y

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Installing LazyVim for '$username'..."
if [ -d "$user_home/.config/nvim" ]; then
  echo "Backing up existing nvim config..."
  sudo mv "$user_home/.config/nvim" "$user_home/.config/nvim.bak.$(date +%s)"
fi

sudo -u "$username" git clone https://github.com/LazyVim/starter "$user_home/.config/nvim"
sudo rm -rf "$user_home/.config/nvim/.git"
sudo chown -R "$username:$username" "$user_home/.config/nvim"

echo "Apt setup completed successfully"
