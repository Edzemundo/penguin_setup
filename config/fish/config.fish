# CachyOS-specific config (only loaded on CachyOS)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Homebrew (Linuxbrew)
if test -x /home/linuxbrew/.linuxbrew/bin/brew
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv fish)"
end

if status is-interactive
    # Commands to run in interactive sessions can go here

    # alias z="zellij"
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

    if status is-interactive
        eval (zellij setup --generate-auto-start fish | string collect)
    end

    fzf --fish | source
    zoxide init fish | source
    # atuin init fish | source

end
