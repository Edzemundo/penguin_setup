# CachyOS-specific config (only loaded on CachyOS)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Homebrew — detect platform and set up environment
if test -d /opt/homebrew
    # macOS Apple Silicon
    eval (/opt/homebrew/bin/brew shellenv)
else if test -d /usr/local/Homebrew
    # macOS Intel
    eval (/usr/local/bin/brew shellenv)
else if test -x /home/linuxbrew/.linuxbrew/bin/brew
    # Linux
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end

if status is-interactive
    alias ls="eza --color=always --long --git --icons=always"
    alias lg="lazygit"
    alias ld="lazydocker"
    alias ff="fastfetch"
    alias nv="nvim"
    alias zed="zeditor"

    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    eval (zellij setup --generate-auto-start fish | string collect)

    fzf --fish | source
    zoxide init fish | source
    atuin init fish | source

    theme_tokyonight night

    fastfetch

end
