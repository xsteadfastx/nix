# vim: tabstop=2 shiftwidth=2 softtabstop=2 expandtab

fish_vi_key_bindings
# fish_default_key_bindings

# set default user
set default_user marv

# FIXME: Shouldnt be needed!
# set -gx LC_ALL "en_US.utf-8"

# clean abbrs
abbr --erase (abbr --list)

# set default editor
set -gx EDITOR nvim

# clean fish_user_paths
set -e fish_user_paths

# sbin
if test -d /sbin
    set fish_user_paths /sbin $fish_user_paths
end

# poetry
if test -d ~/.poetry
    set fish_user_paths ~/.poetry/bin $fish_user_paths
end

# go
set -gx GOPATH ~/.local/share/go
set fish_user_paths ~/.local/share/go/bin $fish_user_paths

# gpg terminal agent
if type -q gpg-agent
    if [ (pgrep -x -u $USER gpg-agent) ]
    else
        gpg-connect-agent /bye >/dev/null 2>&1
    end
    set -x GPG_TTY (tty)
end

# gopass
if type -q gopass
    status --is-interactive; and gopass completion fish | source
end

# brew
if test -f /home/linuxbrew/.linuxbrew/bin/brew
    set -gx HOMEBREW_PREFIX "/home/linuxbrew/.linuxbrew"
    set -gx HOMEBREW_CELLAR "/home/linuxbrew/.linuxbrew/Cellar"
    set -gx HOMEBREW_REPOSITORY "/home/linuxbrew/.linuxbrew/Homebrew"
    set fish_user_paths /home/linuxbrew/.linuxbrew/bin $fish_user_paths
    set fish_user_paths /home/linuxbrew/.linuxbrew/sbin $fish_user_paths
    set fish_function_path /home/linuxbrew/.linuxbrew/share/fish/vendor_completions.d $fish_function_path
end

# asdf
if type -q asdf
    set -x ASDF_DIR (brew --prefix asdf)/libexec
    set fish_user_paths  $ASDF_DIR/bin $fish_user_paths
    set fish_user_paths  ~/.asdf/shims $fish_user_paths
    . $ASDF_DIR/asdf.fish
end

# nix
if test -f ~/.nix-profile/bin/nix
  source ~/.nix-profile/etc/profile.d/nix.fish
  if type -q babelfish
    babelfish < ~/.nix-profile/etc/profile.d/hm-session-vars.sh | source
  end
end

# starship
if type -q starship
    starship init fish | source
end

# krew
if test -d ~/.krew/bin
    set fish_user_paths ~/.krew/bin $fish_user_paths
end

# direnv
if type -q direnv
    direnv hook fish | source
end

# grc
if type -q grc
    set -U grc_plugin_execs cat cvs df diff dig gcc g++ ls ifconfig \
        make mount mtr netstat ping ps tail traceroute \
        wdiff blkid du dnf docker docker-machine env id ip iostat \
        last lsattr lsblk lspci lsmod lsof getfacl getsebool ulimit uptime nmap \
        fdisk findmnt free semanage sar ss sysctl systemctl stat showmount \
        tcpdump tune2fs vmstat w who

    for executable in $grc_plugin_execs
        if type -q $executable
            function $executable --inherit-variable executable --wraps=$executable
                if isatty 1
                    grc $executable $argv
                else
                    eval command $executable $argv
                end
            end
        end
    end
end

# pgadmin4
if test -f /usr/pgadmin4/bin/pgadmin4
    set fish_user_paths /usr/pgadmin4/bin $fish_user_paths
end

# git-fuzzy
if test -d ~/library/apps/git-fuzzy
    set fish_user_paths ~/library/apps/git-fuzzy/bin $fish_user_paths
end

# home paths
if test -d ~/.local/bin
    set fish_user_paths ~/.local/bin $fish_user_paths
end

set fish_user_paths ~/bin $fish_user_paths

if test -d ~/bin/(uname -m)
    set fish_user_paths ~/bin/(uname -m) $fish_user_paths
end

if test -d ~/bin/(hostname)
    set fish_user_paths ~/bin/(hostname) $fish_user_paths
end

# theme
function fish_greeting
    if type -q fortlit
        fortlit
    end
end

# bat
if type -q bat
    set -gx BAT_THEME Dracula
    abbr -a cat bat
end

# fzf
if type -q fzf
    set -gx FZF_DEFAULT_OPTS '
      --layout=reverse
      --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
      --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
      --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
      --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    '
end

# vim
if type -q nvim
    abbr -a vim nvim
end

# radio
abbr -a coderadio 'tmux rename-window coderadio; mpv http://coderadio-admin.freecodecamp.org/radio/8010/radio.mp3'
abbr -a chillradio 'tmux rename-window chillradio; streamlink "https://www.youtube.com/watch?v=jfKfPfyJRdk" 720p -p "mpv --no-video"'
abbr -a synthwaveradio 'tmux rename-window synthwaveradio; mpv --no-video "https://www.youtube.com/watch?v=4xDzrJKXOOY"'

# ls
if type -q exa
    abbr -a ll 'exa --git -la'
else
    abbr -a ll 'ls -la'
end

# search
abbr -a fd 'fd -I'
abbr -a rg 'rg --no-ignore-vcs --hidden'
abbr -a prev "fzf --preview 'bat --style=numbers --color=always {}'"

# gping
if type -q gping
    abbr -a ping gping
end

# viddy
if type -q viddy
    abbr -a watch viddy
end

# kubernetes
abbr -a k kubectl
abbr -a ks 'set -gx KUBECONFIG (fd -I -t f --exact-depth 1 . ~/.kube|fzf)'

# git
abbr -a g git
abbr -a ga 'git add -A'
abbr -a gc 'git commit'
abbr -a gco 'git checkout'
abbr -a gd 'git diff'

abbr -a gu 'git remote update --prune'
abbr -a gs 'git status'
abbr -a gp 'git push --tags'

abbr -a gt 'git tag -l --sort=v:refname'

abbr -a gw 'git worktree'

# ssh
abbr -a ssh 'TERM=xterm-256color SHELL=/bin/sh ssh'

# yaegi
abbr -a yaegi 'rlwrap yaegi'

# jellyfin-mpv-shim
abbr -a jellyfin-mpv flatpak run com.github.iwalton3.jellyfin-mpv-shim/x86_64/stable

# neomutt
if type -q neomutt
    abbr -a mutt neomutt
end

# cp with progress bar
abbr -a rcp rsync -ah --info=progress2

# mv with progress bar
abbr -a rmv rsync -ah --info=progress2 --remove-source-files

# terraform
abbr -a tf terraform

# task
abbr -a t task

# prepare ssh
# fish_ssh_agent
