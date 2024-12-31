# Description: Start ssh-agent and add all keys.

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
