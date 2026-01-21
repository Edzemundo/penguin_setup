#!/bin/bash

# Get username from parameter
if [ -z "$1" ]; then
  echo "Error: Username not provided"
  echo "Usage: ./brew_setup.sh <username>"
  exit 1
fi

username="$1"

echo "Installing and configuring brew for '$username'..."

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Set up brew environment for current session
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Add brew to user's bashrc
echo >> /home/$username/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/$username/.bashrc

# Add brew to user's fish config if fish is installed
if [ -d "/home/$username/.config/fish" ]; then
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/$username/.config/fish/config.fish
fi

echo "Installing brew packages..."
brew update && brew upgrade
brew install gcc bat zellij yazi dust eza lazygit lazydocker fzf ripgrep fd fastfetch neovim zoxide

echo "Brew installed successfully"
