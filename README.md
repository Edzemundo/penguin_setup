# 🐧 Penguin Setup

Automate your Linux development environment setup in minutes instead of hours.

This project bootstraps a modern, productive CLI environment with Fish shell, Homebrew, and a curated selection of developer tools across Debian, Fedora, and Arch-based distributions.

## ✨ What Gets Installed

### Core Tools (via system package manager)
| Tool | Description |
|------|-------------|
| `git` | Version control |
| `curl` | Data transfer tool |
| `build-essential` / `development-tools` / `base-devel` | Compilers and build tools |
| `gh` | GitHub CLI |
| `nano` | Simple text editor |
| `btop` | System monitor |
| `fzf` | Fuzzy finder |
| `npm` | Node.js package manager |
| `luarocks` | Lua package manager |
| `neovim` | Modern Vim-based editor |

### Python Tools
| Tool | Description |
|------|-------------|
| `uv` | Fast Python package manager |

### Homebrew Packages
| Tool | Description |
|------|-------------|
| `gcc` | GNU Compiler Collection |
| `bat` | Cat clone with syntax highlighting |
| `zellij` | Terminal multiplexer |
| `yazi` | Terminal file manager |
| `dust` | Disk usage analyzer |
| `eza` | Modern `ls` replacement |
| `lazygit` | Git TUI |
| `lazydocker` | Docker TUI |
| `fzf` | Fuzzy finder |
| `ripgrep` | Fast grep alternative |
| `fd` | Fast find alternative |
| `fastfetch` | System info display |

### Shell & Editor
- **Fish Shell** - Modern, user-friendly shell
- **LazyVim** - Pre-configured Neovim distribution

## 📁 Included Configurations

Pre-configured dotfiles for:
- `alacritty` - GPU-accelerated terminal
- `kitty` - Feature-rich terminal
- `fish` - Fish shell with aliases and yazi integration
- `yazi` - Terminal file manager

## 🖥️ Supported Distributions

| Distribution | Package Manager | Status |
|--------------|-----------------|--------|
| Ubuntu / Debian | apt | ✅ Supported |
| Fedora / RHEL | dnf | ✅ Supported |
| Arch / Manjaro | pacman | ✅ Supported |

## 📋 Prerequisites

- A supported Linux distribution
- `sudo` privileges
- Internet connection
- `curl` installed

## 🚀 Installation

### Quick Start (One-liner)

```bash
sudo curl -O https://raw.githubusercontent.com/Edzemundo/penguin_setup/refs/heads/main/starter.sh && sudo /bin/bash starter.sh
```

### Manual Installation (Recommended for security-conscious users)

```bash
# Clone the repository
git clone https://github.com/Edzemundo/penguin_setup.git
cd penguin_setup

# Review the scripts before running (recommended)
less setup.sh
less apt_setup.sh  # or dnf_setup.sh / pacman_setup.sh

# Make scripts executable
chmod +x *.sh

# Run the setup with your username
sudo ./setup.sh $USER
```

## 🔒 Security Note

The quick start method uses `curl | bash`, which pipes remote code directly to your shell. While convenient, this pattern has security implications:

- You're trusting the remote server hasn't been compromised
- You can't review the code before execution

**For better security:**
1. Use the manual installation method
2. Review all scripts before running them
3. Verify the repository source

## 🧪 Testing with Docker

A Dockerfile is included for testing the setup without affecting your system:

```bash
# Build the test image
docker build -t penguin-test .

# Run interactively
docker run -it penguin-test

# Inside the container, run:
sudo ./setup.sh tester
```

## 📝 Post-Installation

After installation completes:

1. **Restart your computer** to ensure all changes take effect
2. Fish shell will be available but not set as default - run `chsh -s /usr/bin/fish` to set it
3. Zellij will auto-start in Fish interactive sessions
4. Use `y` alias to launch yazi with directory changing support

## 🎨 Fish Shell Aliases

The fish config includes these aliases:
- `ls` → `eza --color=always --long --git --icons=always`
- `y` → Launch yazi with cwd tracking

## 🤝 Contributing

Feel free to open issues or pull requests to improve this setup!

## 📄 License

MIT License - Feel free to use and modify as needed.

## 🤖 AI usage

Originally created without AI but now used as it makes fixing issues faster.
