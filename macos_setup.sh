#!/bin/bash

# Get username from parameter
if [ -z "$1" ]; then
  echo "Error: Username not provided"
  echo "Usage: ./macos_setup.sh <username>"
  exit 1
fi

username="$1"
user_home="$HOME"

echo "Installing packages for macOS..."

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Please complete the Xcode Command Line Tools installation and run this script again."
  exit 1
else
  echo "Xcode Command Line Tools already installed"
fi

# Install Homebrew if not present (handled in brew_setup.sh)
# This script focuses on system-level packages

echo "Installing packages via Homebrew..."

# Ensure brew is available
if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew not found. Please run brew_setup.sh first."
  exit 1
fi

# Install packages that would normally come from apt/dnf/pacman on Linux
# Many of these are already available via Xcode CLI tools, but we'll ensure they're present
brew install git curl gh nano btop fzf node luarocks rsync

# Install uv (Python package manager)
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "macOS package installation complete"
