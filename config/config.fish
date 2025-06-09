eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

if status is-interactive
    # Commands to run in interactive sessions can go here

    alias z="zellij"
    alias ls="eza --color=always --long --git --icons=always"

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

end
