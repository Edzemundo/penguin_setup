#!/bin/bash

# Function to display error messages
error() {
  echo -e "\e[91mError: $1\e[0m" >&2
  exit 1
}

# Get username
if [ -z "$1" ]; then
  echo "No input provided. Please provide username: "
  read username
else
  username="$1"
fi

# Check if the user exists
if ! id "$username" &>/dev/null; then
  error "User '$username' does not exist."
fi

# Determine user home directory based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  USER_HOME="$HOME"
  OS="macos"
else
  USER_HOME="/home/$username"
  OS="linux"
fi

echo "Setting up for '$username'..."
mkdir -p $USER_HOME/.config/

# Function to detect OS and package manager
detect_system() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS system detected"
    OS="macos"
    PM="brew"
  elif command -v apt &>/dev/null; then
    echo "Debian-based system detected"
    OS="linux"
    PM="apt"
  elif command -v dnf &>/dev/null; then
    echo "Fedora-based system detected"
    OS="linux"
    PM="dnf"
  elif command -v pacman &>/dev/null; then
    echo "Arch-based system detected"
    OS="linux"
    PM="pacman"
  else
    error "No supported package manager found"
  fi
}

# Function to run setup scripts
install() {
  # Run OS-specific setup
  if [ "$OS" = "macos" ]; then
    echo "Installing Brew..."
    ./brew_setup.sh "$username" || error "Failed to install Brew"
    
    echo "Running macOS setup..."
    ./macos_setup.sh "$username" || error "Failed to run macOS setup"
  else
    # Run Linux package manager specific setup
    if [ "$PM" = "apt" ]; then
      echo "Running apt setup..."
      ./apt_setup.sh "$username" || error "Failed to run apt setup"
    elif [ "$PM" = "dnf" ]; then
      echo "Running dnf setup..."
      ./dnf_setup.sh "$username" || error "Failed to run dnf setup"
    elif [ "$PM" = "pacman" ]; then
      echo "Running pacman setup..."
      ./pacman_setup.sh "$username" || error "Failed to run pacman setup"
    fi

    echo "Installing Brew..."
    ./brew_setup.sh "$username" || error "Failed to install Brew"
  fi

  echo "Installing Fish shell..."
  ./fish_setup.sh || error "Failed to install Fish"

  echo "Installation complete"
}

config() {
  echo "Copying config files..."

  CONFIG_DIRS=("alacritty" "kitty" "fish" "yazi" "zellij" "nvim")

  for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "./config/$dir" ]; then
      # Use sudo only on Linux, not needed on macOS for own files
      if [ "$OS" = "macos" ]; then
        rm -rf $USER_HOME/.config/$dir
        mkdir -p $USER_HOME/.config/$dir
        rsync -a --exclude='.git' ./config/$dir/ $USER_HOME/.config/$dir/
      else
        sudo rm -rf $USER_HOME/.config/$dir
        sudo mkdir -p $USER_HOME/.config/$dir
        sudo rsync -a --exclude='.git' ./config/$dir/ $USER_HOME/.config/$dir/
      fi
    else
      echo "Warning: ./config/$dir not found, skipping"
    fi
  done

  # Fix ownership on Linux only
  if [ "$OS" = "linux" ]; then
    echo "Changing ownership of config files..."
    sudo chown -R $username:$username $USER_HOME/.config
  fi
}

# Main script execution
main() {
  echo "Running setup script..."
  echo "-----------------------------"

  # Detect OS and package manager
  detect_system

  # Run install script
  install

  # Copy config files
  config

  echo ""
  if [ "$OS" = "macos" ]; then
    echo "Setup complete! Please restart your terminal or run: exec fish"
    echo "To set Fish as default shell, run: chsh -s $(which fish)"
  else
    echo "PLEASE RESTART COMPUTER TO COMPLETE SETUP."
  fi
  echo ""
}

# Run the script
main
