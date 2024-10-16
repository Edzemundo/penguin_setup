if status is-interactive
    # Commands to run in interactive sessions can go here
    status --is-interactive; and source (pyenv virtualenv-init -|psub)
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    export PYENV_VIRTUALENV_DISABLE_PROMPT=1

    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    alias z="zellij"
    alias ls="eza --color=always --long --git --icons=always"
    fzf --fish | source

    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

end
