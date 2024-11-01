#!/bin/bash

mkdir -p ~/.config/

echo "updating apt..."
sudo apt update && sudo apt upgrade -y

echo "Installing apt packages"
sudo apt install git curl build-essential alacritty btop bat fzf thefuck neofetch -y

echo "Setup completed successfully!"
