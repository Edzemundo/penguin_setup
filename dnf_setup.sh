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
sudo dnf install git curl vim neovim nodejs npm btop fzf gh nano luarocks sqlite-devel rsync -y
sudo dnf group install development-tools -y

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Dnf setup completed successfully"
