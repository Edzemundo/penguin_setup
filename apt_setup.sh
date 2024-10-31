#!/bin/bash

mkdir -p ~/.config/

echo "updating apt..."
sudo apt update && sudo apt upgrade -y

echo "Installing and configuring fish"
sudo apt install fish -y
if ! grep -q "^/usr/bin/fish$" /etc/shells; then
  echo "/usr/bin/fish" >>/etc/shells
fi
chsh -s $(which fish)

echo "Installing apt packages"
sudo apt install git curl btop bat eza fzf thefuck -y

echo "Installing and configuring brew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Installing brew packages"
brew update && brew upgrade
brew install zellij dust tlrc pyenv-virtualenv nvim
brew install --cask alacritty

echo "Copying config files..."
cp -rf config/* ~/.config/

echo "Setup completed successfully!"
