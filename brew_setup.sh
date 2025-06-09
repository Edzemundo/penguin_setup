#!/bin/bash

echo "Installing and configuring brew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# echo >>~/.config/fish/config.fish
# echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>~/.config/fish/config.fish
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "Installing brew packages"
brew update && brew upgrade
brew install gcc bat zellij yazi dust eza tlrc nvim
brew install jesseduffield/lazygit/lazygit
brew install jesseduffield/lazydocker/lazydocker

echo "Brew installed successfully"
