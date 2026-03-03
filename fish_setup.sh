#!/bin/bash

FISH_PATH="/usr/bin/fish"
FISH_PATH_2="/usr/sbin/fish"

if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Installing and configuring fish on macOS"
  
  # Check if fish is already installed
  if ! command -v fish &>/dev/null; then
    # Install via Homebrew
    if command -v brew &>/dev/null; then
      brew install fish
    else
      echo "Error: Homebrew not found. Please install Homebrew first."
      exit 1
    fi
  else
    echo "Fish already installed"
  fi
  
  # Get fish path from brew
  FISH_PATH=$(which fish)

elif command -v apt &>/dev/null; then
  echo "Installing and configuring fish"
  sudo apt install fish -y

elif command -v dnf &>/dev/null; then
  echo "Installing and configuring fish"
  sudo dnf install fish -y

elif command -v pacman &>/dev/null; then
  echo "Installing and configuring fish"
  sudo pacman -Sy fish --noconfirm

else
  echo "Error: No supported package manager found"
  exit 1
fi

# Register fish shell
echo "Registering fish shell"
if ! grep -q "^${FISH_PATH}$" /etc/shells 2>/dev/null; then
  echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
fi

if [ -n "$FISH_PATH_2" ] && ! grep -q "^${FISH_PATH_2}$" /etc/shells 2>/dev/null; then
  echo "$FISH_PATH_2" | sudo tee -a /etc/shells > /dev/null
fi

# Create symlink for compatibility with configs expecting /usr/local/bin/fish
if [ ! -e /usr/local/bin/fish ] && [ -x /usr/bin/fish ]; then
  echo "Creating symlink /usr/local/bin/fish -> /usr/bin/fish"
  sudo ln -s /usr/bin/fish /usr/local/bin/fish
fi

echo "Fish installed successfully"
