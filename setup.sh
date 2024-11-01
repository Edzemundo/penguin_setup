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
    ./$INSTALL_SCRIPT
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

# Main script execution
main() {
  echo "Running setup script..."
  echo "-----------------------------"

  # Check if running as root
  check_root

  # Detect package manager
  detect_package_manager

  #run install script
  install

  echo "Please restart computer to complete setup."
}

# Run the script
main
