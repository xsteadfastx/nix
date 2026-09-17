function wip
	set -l proj (ls ~/wip/|fzf)
	if set -q TMUX
		tmux rename-window $proj
	else if set -q ZELLIJ
		zellij action rename-tab $proj
	end
	cd ~/wip/$proj
end
