if not pgrep --full ssh-agent | string collect > /dev/null
	eval (ssh-agent -c)
	set -Ux SSH_AGENT_PID $SSH_AGENT_PID
	set -Ux SSH_AUTH_SOCK $SSH_AUTH_SOCK

	if type -q gopass
		for key in (gopass ls -f ssh/)
			gopass show -n $key | ssh-add - 2>/dev/null
		end
	end
end
