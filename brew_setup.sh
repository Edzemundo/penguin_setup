#!/bin/bash

# Get username from parameter
if [ -z "$1" ]; then
  echo "Error: Username not provided"
  echo "Usage: ./brew_setup.sh <username>"
  exit 1
fi

username="$1"

echo "Installing and configuring brew for '$username'..."

# Detect OS and set appropriate paths
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  USER_HOME="$HOME"
  # Detect Apple Silicon vs Intel Mac
  if [ -d "/opt/homebrew" ]; then
    BREW_PREFIX="/opt/homebrew"
  elif [ -d "/usr/local/Homebrew" ]; then
    BREW_PREFIX="/usr/local"
  else
    BREW_PREFIX=""
  fi
else
  # Linux
  USER_HOME="/home/$username"
  BREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

# Install Homebrew if not already installed
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Update BREW_PREFIX after installation if it was empty
  if [[ "$OSTYPE" == "darwin"* ]] && [ -z "$BREW_PREFIX" ]; then
    if [ -d "/opt/homebrew" ]; then
      BREW_PREFIX="/opt/homebrew"
    elif [ -d "/usr/local/Homebrew" ]; then
      BREW_PREFIX="/usr/local"
    fi
  fi
else
  echo "Homebrew already installed"
fi

# Set up brew environment for current session
if [ -n "$BREW_PREFIX" ]; then
  eval "$($BREW_PREFIX/bin/brew shellenv)"
fi

# Add brew to user's bashrc if on Linux
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo >> $USER_HOME/.bashrc
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> $USER_HOME/.bashrc
fi

# Add brew to user's fish config if fish is installed
# Fish config will handle multi-platform detection itself
# This is a fallback in case the config doesn't exist yet
if [ -d "$USER_HOME/.config/fish" ]; then
  # Check if already added to avoid duplicates
  if ! grep -q "brew shellenv" "$USER_HOME/.config/fish/config.fish" 2>/dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS - config.fish will handle auto-detection
      : # No-op, let config.fish handle it
    else
      # Linux - add if not present
      echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> $USER_HOME/.config/fish/config.fish
    fi
  fi
fi

echo "Installing brew packages..."
brew update && brew upgrade

# Install packages
# Note: gcc is not needed on macOS (uses Xcode's toolchain)
if [[ "$OSTYPE" == "darwin"* ]]; then
  brew install bat zellij yazi dust eza lazygit lazydocker fzf ripgrep fd fastfetch neovim zoxide atuin
else
  brew install gcc bat zellij yazi dust eza lazygit lazydocker fzf ripgrep fd fastfetch neovim zoxide atuin
fi

echo "Brew installed successfully"
