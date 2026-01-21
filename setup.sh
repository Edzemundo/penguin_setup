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

echo "Setting up for '$username'..."
mkdir -p /home/$username/.config/

# Function to detect package manager
detect_package_manager() {
  if command -v apt &>/dev/null; then
    echo "Debian-based system detected"
    PM="apt"
  elif command -v dnf &>/dev/null; then
    echo "Fedora-based system detected"
    PM="dnf"
  elif command -v pacman &>/dev/null; then
    echo "Arch-based system detected"
    PM="pacman"
  else
    error "No supported package manager found"
  fi
}

# Function to run setup scripts
install() {
  # Run package manager specific setup
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

  echo "Installing Fish shell..."
  ./fish_setup.sh || error "Failed to install Fish"

  echo "Installing Brew..."
  ./brew_setup.sh "$username" || error "Failed to install Brew"

  echo "Installation complete"
}

config() {
  echo "Copying config files..."

  CONFIG_DIRS=("alacritty" "kitty" "fish" "yazi")

  for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "./config/$dir" ]; then
      sudo rm -rf /home/$username/.config/$dir
      sudo cp -rf ./config/$dir /home/$username/.config/
    else
      echo "Warning: ./config/$dir not found, skipping"
    fi
  done

  echo "Changing ownership of config files..."
  sudo chown -R $username:$username /home/$username/.config
}

# Main script execution
main() {
  echo "Running setup script..."
  echo "-----------------------------"

  # Detect package manager
  detect_package_manager

  # Run install script
  install

  # Copy config files
  config

  echo ""
  echo "PLEASE RESTART COMPUTER TO COMPLETE SETUP."
  echo ""
}

# Run the script
main
