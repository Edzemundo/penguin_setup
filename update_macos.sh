#!/bin/bash
set -e

# Function to display error messages
error() {
  echo -e "\e[91mError: $1\e[0m" >&2
  exit 1
}

# This script only makes sense on macOS
[[ "$OSTYPE" == "darwin"* ]] || error "This script is for macOS only."

# Work from the repo root regardless of where this script was invoked from
cd "$(dirname "${BASH_SOURCE[0]}")"

# Parse flags
HEADLESS=false
for arg in "$@"; do
  [[ "$arg" == "--headless" ]] && HEADLESS=true
done

USER_HOME="$HOME"

echo "Pulling latest config changes..."
git pull || error "git pull failed"

echo "Copying config files..."

BASE_DIRS=("fish" "nvim" "yazi" "zellij" "btop" "fastfetch" "git")
DESKTOP_DIRS=("kitty" "ghostty" "hypr" "waybar" "walker" "zed")

if [ "$HEADLESS" = true ]; then
  echo "Headless mode: skipping desktop configs"
  CONFIG_DIRS=("${BASE_DIRS[@]}")
else
  CONFIG_DIRS=("${BASE_DIRS[@]}" "${DESKTOP_DIRS[@]}")
fi

for dir in "${CONFIG_DIRS[@]}"; do
  if [ -d "./config/$dir" ]; then
    rm -rf "$USER_HOME/.config/$dir"
    mkdir -p "$USER_HOME/.config/$dir"
    rsync -a --exclude='.git' "./config/$dir/" "$USER_HOME/.config/$dir/"
  else
    echo "Warning: ./config/$dir not found, skipping"
  fi
done

echo ""
echo "Config update complete! Restart your terminal (or run: exec fish) to pick up changes."
