function wip
	set -l proj (ls ~/wip/|fzf)
	tmux rename-window $proj
	cd ~/wip/$proj
end
