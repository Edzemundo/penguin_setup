#!/bin/bash

echo "Installing and configuring fish"
sudo apt install fish -y
if ! grep -q "^/usr/bin/fish$" /etc/shells; then
  echo "/usr/bin/fish" >>/etc/shells
fi
chsh -s $(which fish)
su "$USER"
chsh -s $(which fish)
echo "Fish installed successfully"
