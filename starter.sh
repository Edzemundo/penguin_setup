#!/bin/bash
set -e

git clone https://github.com/Edzemundo/penguin_setup.git
cd penguin_setup
chmod +x *.sh
./setup.sh "${SUDO_USER:-$USER}" "$@"
