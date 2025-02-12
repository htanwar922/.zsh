#!/bin/zsh
export ZPROFILE_IMPORTED=true

export PATH="$PATH:$HOME/.vscode-server/data/User/globalStorage/ms-dotnettools.vscode-dotnet-runtime/.dotnet/7.0.14~x64"

if [ `uname -r | grep "WSL"` ]; then
    # export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
    # export LIBGL_ALWAYS_INDIRECT=1
    # export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

export PROMPT=$'\e[34m┌──(\e[1;31m%n㉿%m\e[0m\e[34m)-[\e[1;37m%~\e[0m\e[34m]
└─\e[1;31m# \e[0m'

if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
