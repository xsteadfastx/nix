function __update_fish_complete_path --on-variable XDG_DATA_DIRS
    for xdg_dir in (string split : $XDG_DATA_DIRS)
        set -l completion_dir $xdg_dir/fish/vendor_completions.d
        if test -d $completion_dir; and not contains $completion_dir $fish_complete_path
            set -p fish_complete_path $completion_dir
        end
    end
end

__update_fish_complete_path
