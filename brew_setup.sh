#!/bin/bash

echo "Installing and configuring brew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >>/root/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>/root/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "Installing brew packages"
brew update && brew upgrade
brew install gcc zellij yazi dust eza tlrc pyenv-virtualenv nvim

echo "Copying config files..."
cp -rf config/* ~/.config/
