#!/bin/bash

# Function to display error messages
error() {
  echo -e "\e[91mError: $1\e[0m" >&2
  exit 1
}

# Function to check if running as root
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root or with sudo privileges"
  fi
}

# Get username
if [ -z "$1" ]; then
  error "No input provided. Please provide username as an argument."
fi

username="$1"

# Check if the user exists
if id "$username" &>/dev/null; then
  echo "Setting up for '$username'..."
  echo "Creating user .config folder..."
  sudo mkdir -p /home/$username/.config/
else
  error "User '$username' does not exist."
fi

# Function to detect package manager
detect_package_manager() {
  if command -v apt &>/dev/null; then
    echo "debian-based system detected"
    PM="apt"
    INSTALL_SCRIPT="apt_setup.sh"
  elif command -v dnf &>/dev/null; then
    PM="dnf"
    INSTALL_SCRIPT="dnf_setup.sh"
  elif command -v pacman &>/dev/null; then
    PM="pacman"
    INSTALL_SCRIPT="pacman_setup.sh"
  else
    error "No supported package manager found"
  fi
}

# Function to run setup script
install() {

  case $PM in
  "apt")
    # For Debian/Ubuntu based systems
    echo "Running apt setup..."
    sudo -u $username ./fish_setup.sh $username
    ./$INSTALL_SCRIPT
    sudo -u $username ./brew_setup.sh $username
    ;;
  "dnf" | "yum")
    # For RHEL/Fedora based systems
    ./$INSTALL_SCRIPT
    ;;
  "pacman")
    # For Arch Linux
    ./$INSTALL_SCRIPT
    ;;
  esac

  if [ $? -ne 0 ]; then
    error "Failed to install"
  fi
}

config() {
  echo "Copying config files..."

  sudo mkdir -p /home/$username/.config && sudo cp -rf ./config/alacritty /home/$username/.config/
  sudo cp -rf ./config/btop /home/$username/.config/
  sudo mkdir -p /home/$username/.config/fish && sudo cp -rf ./config/config.fish /home/$username/.config/fish/
  sudo mkdir -p /home/$username/.config/yazi && sudo cp -rf ./config/yazi.toml /home/$username/.config/yazi/
  sudo mkdir -p /home/$username/.config/nvim && git clone https://github.com/LazyVim/starter /home/$username/.config/nvim

  # Check if the copying operation was successful
  if [ $? -eq 0 ]; then
    echo "Config files copied successfully"
  else
    echo "Error: Failed to copy config files" >&2
    exit 1
  fi

}

# Main script execution
main() {
  echo "Running setup script..."
  echo "-----------------------------"

  # Check if running as root
  check_root

  # Detect package manager
  detect_package_manager

  # Copy config files
  config

  #run install script
  install

  echo "Changing ownership of config files..."
  sudo chown -R $username:$username /home/$username/.config

  echo "Please restart computer to complete setup."
}

# Run the script
main
