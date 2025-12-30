#!/bin/bash

echo "Installing and configuring brew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Add brew to Fish config
echo "Configuring brew for fish shell"
mkdir -p ~/.config/fish
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.config/fish/config.fish

echo "Installing brew packages"
brew update && brew upgrade
brew install gcc bat zellij yazi dust eza dust lazygit lazydocker fzf ripgrep fd

echo "Brew installed successfully"
