#!/bin/zsh
export ZPROFILE_IMPORTED=true

export PATH="$PATH:/home/himanshu/.vscode-server/data/User/globalStorage/ms-dotnettools.vscode-dotnet-runtime/.dotnet/7.0.14~x64"

if [ `uname -r | grep "WSL"` ]; then
    # export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
    # export LIBGL_ALWAYS_INDIRECT=1
    # export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

# Import all .zsh files in ~/.zsh
for file in ~/.zsh/*.zsh; do
    source $file
done

