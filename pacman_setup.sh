#!/bin/bash

mkdir -p ~/.config/

echo "updating pacman..."
sudo pacman -Syu

echo "Installing pacman packages"
sudo pacman -Sy git curl build-essential alacritty btop bat fzf thefuck neofetch --noconfirm

echo "Setup completed successfully!"
