#!/bin/bash

echo "updating dnf..."
sudo dnf update && sudo dnf upgrade -y

echo "Installing dnf packages"
sudo dnf install git curl build-essential uv -y

echo "Dnf setup completed successfully"
