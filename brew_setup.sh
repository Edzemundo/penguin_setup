#!/bin/bash

echo "Installing and configuring brew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >>/root/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>/root/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "Installing brew packages"
brew update && brew upgrade
brew install gcc bat zellij yazi dust eza tlrc pyenv-virtualenv nvim gh lazydocker lazygit

echo "Brew installed successfully"
