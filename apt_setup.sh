#!/bin/bash

echo "updating apt..."
sudo apt update && sudo apt upgrade -y

echo "Installing apt packages"
sudo apt install git curl build-essential btop fzf thefuck neofetch -y

echo "Apt setup completed successfully"
