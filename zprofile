#!/bin/zsh
export ZPROFILE_IMPORTED=true

export PATH="$PATH:/home/himanshu/.vscode-server/data/User/globalStorage/ms-dotnettools.vscode-dotnet-runtime/.dotnet/7.0.14~x64"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || echo -n
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" || echo -n

if [ `uname -r | grep "WSL"` ]; then
    # export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
    # export LIBGL_ALWAYS_INDIRECT=1
    # export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

SSH_ENV="/tmp/.ssh-agent-environment"
function ssh-agent-start {
   echo "Initialising new SSH agent..."
   /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
   echo succeeded
   chmod 600 "${SSH_ENV}"
   . "${SSH_ENV}" > /dev/null
   /usr/bin/ssh-add;
}
if [ -f "${SSH_ENV}" ]; then
   . "${SSH_ENV}" > /dev/null
   #ps ${SSH_AGENT_PID} doesn't work under cywgin
   ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
       ssh-agent-start;
   }
else
   ssh-agent-start;
fi

function add-timestamp {
    # ts '[%Y-%m-%d %H:%M:%S]'
    while read line; do echo "[$(date +'%Y-%m-%d %H:%M:%S.%3N')] $line"; done
}
