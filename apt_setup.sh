#!/bin/bash

echo "updating apt..."
sudo apt update && sudo apt upgrade -y

echo "Installing apt packages"
sudo apt install git curl build-essential libsqlite3-dev gh nano btop fzf npm luarocks -y

echo "Installing uv"
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Apt setup completed successfully"
