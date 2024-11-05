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

echo "Please enter your username:"
read username

echo "Cloning git repo..."
git clone https://github.com/Edzemundo/penguin_setup
echo "Changing directory..."
cd penguin_setup && sudo ./setup.sh
