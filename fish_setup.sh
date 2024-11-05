#!/bin/bash

if command -v apt &>/dev/null; then
  echo "Installing and configuring fish"
  sudo apt install fish -y
  if ! grep -q "^/usr/bin/fish$" /etc/shells; then
    echo "/usr/bin/fish" >>/etc/shells
  fi
  # su "$USER"
  # sudo -u $username chsh -s $(which fish)
  echo "Fish installed successfully"

elif command -v dnf &>/dev/null; then
  echo "Installing and configuring fish"
  sudo dnf install fish -y
  if ! grep -q "^/usr/bin/fish$" /etc/shells; then
    echo "/usr/bin/fish" >>/etc/shells
  fi
  su "$USER"
  chsh -s $(which fish)
  echo "Fish installed successfully"

elif command -v pacman &>/dev/null; then
  echo "Installing and configuring fish"
  sudo pacman -Sy fish --noconfirm
  if ! grep -q "^/usr/bin/fish$" /etc/shells; then
    echo "/usr/bin/fish" >>/etc/shells
  fi
  su "$USER"
  chsh -s $(which fish)
  echo "Fish installed successfully"

else
  error "No supported package manager found"
fi

echo "Installing and configuring fish"
sudo apt install fish -y
if ! grep -q "^/usr/bin/fish$" /etc/shells; then
  echo "/usr/bin/fish" >>/etc/shells
fi
su "$USER"
chsh -s $(which fish)
$SHELL
echo "Fish installed successfully"
