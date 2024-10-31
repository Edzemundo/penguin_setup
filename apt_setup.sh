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
sudo apt install git curl build-essential alacritty btop bat fzf thefuck neofetch -y

echo "Installing and configuring brew..."
su "$USER"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >>/root/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>/root/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "Installing brew packages"
brew update && brew upgrade
brew install gcc zellij dust eza tlrc pyenv-virtualenv nvim

echo "Copying config files..."
cp -rf config/* ~/.config/

echo "Setup completed successfully!"
