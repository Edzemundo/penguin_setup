if status is-interactive
    # Commands to run in interactive sessions can go here

    # Run fastfetch
    fastfetch

    # Homebrew setup
    if test -d /home/linuxbrew/.linuxbrew
        eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
    end

    # Alias ls to eza with nice defaults
    alias ls="eza --color=always --long --git --icons=always"

    # Yazi wrapper function with directory changing support
    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # Auto-start zellij
    eval (zellij setup --generate-auto-start fish | string collect)

    # Zoxide init
    zoxide init fish | source
end
