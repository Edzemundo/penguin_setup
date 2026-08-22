# Fish shell configuration
# Installed to ~/.config/fish/config.fish
# Reference: https://fishshell.com/docs/current/language.html
#
# Managed by penguin_setup: this file is overwritten by `sync.sh pull`.
# Machine-local additions belong in ~/.config/fish/conf.d/*.fish, which fish
# sources automatically and sync excludes.
#
# Read top to bottom this runs: distro hook, then PATH setup (every shell),
# then the interactive block (prompts and tools, skipped by scripts).

# CachyOS ships its own fish config; load it first if present.
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Homebrew. One config for every platform, so detect the prefix at runtime
# rather than shipping a per-OS file. Same four prefixes load_brew_env probes
# in lib/bootstrap.sh: Apple Silicon, Intel Mac, system-wide Linux, single-user
# Linux.
for brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew $HOME/.linuxbrew
    if test -x $brew_prefix/bin/brew
        eval ($brew_prefix/bin/brew shellenv)
        break
    end
end

if status is-interactive
    # Every tool below is guarded. A config that assumes its tools exist
    # throws errors on every prompt for the whole time between installing a
    # machine and finishing the install -- and breaks the container tests.

    # ls in long form with git status and icons. Icons need a Nerd Font in
    # the terminal or they render as tofu.
    command -q eza && alias ls="eza --color=always --long --git --icons=always"
    command -q lazygit && alias lg="lazygit"
    command -q lazydocker && alias ld="lazydocker"
    command -q fastfetch && alias ff="fastfetch"
    command -q nvim && alias nv="nvim"

    # The Zed CLI is `zeditor` on Linux and `zed` on macOS, where aliasing
    # zed=zed would shadow the real binary with itself.
    command -q zeditor && alias zed="zeditor"

    # yazi, returning to whatever directory you quit in.
    if command -q yazi
        function y
            set tmp (mktemp -t "yazi-cwd.XXXXXX")
            yazi $argv --cwd-file="$tmp"
            if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
                builtin cd -- "$cwd"
            end
            rm -f -- "$tmp"
        end
    end

    command -q zellij && eval (zellij setup --generate-auto-start fish | string collect)

    command -q fzf && fzf --fish | source
    command -q zoxide && zoxide init fish | source
    command -q atuin && atuin init fish | source

    # Installed by fisher; absent until fisher_sync has run once.
    functions -q theme_tokyonight && theme_tokyonight night

    command -q fastfetch && fastfetch
end
