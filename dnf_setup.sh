#!/bin/bash

echo "updating dnf..."
sudo dnf update && sudo dnf upgrade -y

echo "Installing dnf packages"
sudo dnf install git curl uv vim neovim nodejs -y
sudo dnf group install development-tools -y

#reloading shell
echo "Reloading shell..."
echo "Type 'exit' and hit enter to return to the setup script after shell reloads."
exec $SHELL

echo "Installing Lazyvim"
git clone https://github.com/LazyVim/starter ~/.config/nvim

echo "Dnf setup completed successfully"
