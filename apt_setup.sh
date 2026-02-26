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
sudo apt install git curl build-essential libsqlite3-dev gh nano btop fzf npm luarocks rsync -y

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Apt setup completed successfully"
