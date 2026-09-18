{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.unstable.fish
    pkgs.unstable.starship
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    GOPATH = "$HOME/.local/share/go";
    BAT_THEME = "Dracula";
    FZF_DEFAULT_OPTS = ''
      --layout=reverse
      --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
      --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
      --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
      --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4
    '';
  };

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/.krew/bin"
    "$HOME/.local/share/go/bin"
  ];

  # fzf's fish key bindings (fish_user_key_bindings depends on
  # fzf_key_bindings); fzf does not auto-load its bindings into
  # fish_function_path, hence this explicit copy.
  xdg.configFile."fish/functions/fzf_key_bindings.fish".source =
    "${pkgs.unstable.fzf}/share/fzf/key-bindings.fish";

  programs.fish.enable = true;

  # arch/hostname bin dirs cannot be declarative sessionPath; fish_add_path
  # keeps them (prepended) after the session vars are sourced.
  programs.fish.shellInit = ''
    fish_add_path "$HOME/bin/(uname -m)" "$HOME/bin/(hostname)"
  '';

  programs.fish.functions = {
    "2mkv" = {
      body = ''
        HandBrakeCLI --input $argv[1] --output $argv[2] \
          --main-feature --markers --optimize --ipod-atom --encoder-tune film \
          --encoder x264 --encoder-profile high --encoder-preset medium \
          --encoder-level 4.1 --quality 20 --maxWidth 1920 --maxHeight 1080 \
          --decomb --auto-anamorphic --cfr --all-audio \
          --aencoder copy --audio-fallback av_aac --ab 160 --all-subtitles
      '';
    };
    "2mkv265" = {
      body = ''
        HandBrakeCLI --input $argv[1] --output $argv[2] --encoder x265 \
          --encoder-preset medium --quality 18 --decomb --auto-anamorphic --cfr \
          --all-audio --aencoder copy --audio-fallback av_aac --ab 160 --all-subtitles
      '';
    };
    "2mp4" = {
      body = ''
        /usr/bin/HandBrakeCLI --input $argv[1] --output $argv[2] \
          --preset "Fast 1080p30" --audio-lang-list "eng,deu" --all-audio \
          --aencoder copy --audio-fallback av_aac --ab 160 \
          --subtitle-lang-list "eng,deu" --all-subtitles
      '';
    };
    "bkp_christine" = {
      body = ''
        rsync -rv --delete /media/preuss/preussc/ /media/preuss/285C788B05E31012
      '';
    };
    "dig_acme_xsfx" = {
      body = ''
        tmux-xpanes -c "watch -n 5 dig +short @{} TXT _acme-challenge.xsteadfastx.org" ns1.your-server.de 8.8.8.8 1.1.1.1 9.9.9.9
      '';
    };
    "enter" = {
      body = ''
        docker ps --filter status=running --format "table {{.Image}}\t{{.Names}}\t{{.ID}}" | awk 'NR > 1 { print }' | read -z containers
        if [ -z "$containers" ];
            echo -e "No running container found"
        else
            printf $containers | fzf --reverse | awk '{ print $3 }' | read selected_container; or return
            docker exec -it "$selected_container" fish; and return
            docker exec -it "$selected_container" zsh; and return
            docker exec -it "$selected_container" bash; and return;
            docker exec -it "$selected_container" sh;
        end
      '';
    };
    "git-clone-bare-for-worktrees" = {
      argumentNames = [
        "url"
        "destination"
      ];
      body = ''
        set oldDir (pwd)
        if test -d $destination
            echo "$destination already exists"
            return 1
        end
        mkdir $destination
        cd $destination
        git clone --bare $url .bare
        echo "gitdir: ./.bare" > .git
        git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
        cd $oldDir
      '';
    };
    "sudo" = {
      body = ''
        if test "$argv" = !!
            eval command sudo $history[1]
        else
            command sudo $argv
        end
      '';
    };
    "wip" = {
      body = ''
        set -l proj (ls ~/wip/|fzf)
        if set -q TMUX
            tmux rename-window $proj
        else if set -q ZELLIJ
            zellij action rename-tab $proj
        end
        cd ~/wip/$proj
      '';
    };
    fish_greeting = {
      body = ''
        if type -q fortlit
            fortlit
        end
      '';
    };
    fish_mode_prompt = {
      body = ''
        switch $fish_bind_mode
          case default
            set_color --bold red
            echo 'N '
          case insert
            set_color --bold green
            echo 'I '
          case replace_one
            set_color --bold green
            echo 'R '
          case visual
            set_color --bold brmagenta
            echo 'V '
          case '*'
            set_color --bold red
            echo '? '
        end
        set_color normal
      '';
    };
    fish_user_key_bindings = {
      body = ''
        if type -q fzf_key_bindings
            fzf_key_bindings
        end
      '';
    };
    # kept: user relies on ssh-agent (separate live handler is the
    # ssh-agent-prepare block in interactiveShellInit)
    fish_ssh_agent = {
      body = ''
        function __ssh_agent_is_started -d "check if ssh agent is already started"
           if begin; test -f $SSH_ENV; and test -z "$SSH_AGENT_PID"; end
              source $SSH_ENV > /dev/null
           end

           if ! test -S "$SSH_AUTH_SOCK"; return 1; end
           if test -z "$SSH_AGENT_PID"; return 1; end

           ps -ef | grep $SSH_AGENT_PID | grep -v grep | grep -q ssh-agent
           return $status
        end

        function __ssh_agent_start -d "start a new ssh agent"
           ssh-agent -c | sed 's/^echo/#echo/' > $SSH_ENV
           chmod 600 $SSH_ENV
           source $SSH_ENV > /dev/null
           true  # suppress errors from setenv, i.e. set -gx
        end

        function fish_ssh_agent --description "Start ssh-agent if not started yet, or uses already started ssh-agent."
           if test -z "$SSH_ENV"
              set -xg SSH_ENV $HOME/.ssh/environment
           end

           if not __ssh_agent_is_started
              __ssh_agent_start
              ~/bin/ssh-agent-prepare
           end
        end
      '';
    };
  };

  programs.fish.shellAbbrs = {
    ll = "exa --git -la";
    cat = "bat";
    vim = "nvim";
    fd = "fd -I";
    rg = "rg --no-ignore-vcs --hidden";
    prev = "fzf --preview 'bat --style=numbers --color=always {}'";
    watch = "viddy";
    g = "git";
    ga = "git add -A";
    gc = "git commit";
    gco = "git checkout";
    gd = "git diff";
    gu = "git remote update --prune";
    gs = "git status";
    gp = "git push --tags";
    gt = "git tag -l --sort=v:refname";
    gw = "git worktree";
    k = "kubectl";
    ks = "set -gx KUBECONFIG (fd -I -t f --exact-depth 1 . ~/.kube|fzf)";
    tf = "terraform";
    t = "task";
    mutt = "neomutt";
    rcp = "rsync -ah --info=progress2";
    rmv = "rsync -ah --info=progress2 --remove-source-files";
    ssh = "TERM=xterm-256color SHELL=/bin/sh ssh";
    yaegi = "rlwrap yaegi";
    "jellyfin-mpv" = "flatpak run com.github.iwalton3.jellyfin-mpv-shim/x86_64/stable";
    coderadio = "tmux rename-window coderadio; mpv http://coderadio-admin.freecodecamp.org/radio/8010/radio.mp3";
    chillradio = "tmux rename-window chillradio; streamlink https://www.youtube.com/watch?v=jfKfPfyJRdk 720p -p \"mpv --no-video\"";
    synthwaveradio = "tmux rename-window synthwaveradio; mpv --no-video https://www.youtube.com/watch?v=4xDzrJKXOOY";
  };

  # interactive-only init: theme colors, ssh-agent + gopass keys, guarded tool
  # blocks, grc wrappers. Runs after HM applies abbrs/aliases.
  programs.fish.interactiveShellInit = ''
    fish_vi_key_bindings
    set default_user marv

    # dracula colors (formerly conf.d/dracula.fish)
    set -g fish_color_normal f8f8f2
    set -g fish_color_command 8be9fd
    set -g fish_color_keyword ff79c6
    set -g fish_color_quote f1fa8c
    set -g fish_color_redirection f8f8f2
    set -g fish_color_end ffb86c
    set -g fish_color_error ff5555
    set -g fish_color_param bd93f9
    set -g fish_color_comment 6272a4
    set -g fish_color_selection --background=44475a
    set -g fish_color_search_match --background=44475a
    set -g fish_color_operator 50fa7b
    set -g fish_color_escape ff79c6
    set -g fish_color_autosuggestion 6272a4
    set -g fish_pager_color_progress 6272a4
    set -g fish_pager_color_prefix 8be9fd
    set -g fish_pager_color_completion f8f8f2
    set -g fish_pager_color_description 6272a4

    # ssh-agent + gopass keys (formerly conf.d/ssh-agent-prepare.fish)
    if not pgrep --full ssh-agent | string collect > /dev/null
        eval (ssh-agent -c)
        set -gx SSH_AGENT_PID $SSH_AGENT_PID
        set -gx SSH_AUTH_SOCK $SSH_AUTH_SOCK
        if type -q gopass
            for key in (gopass ls -f ssh/)
                gopass show -n $key | ssh-add - 2>/dev/null
            end
        end
    end

    # gpg tty
    if type -q gpg-agent
        set -gx GPG_TTY (tty)
    end

    # gopass completions
    if type -q gopass
        gopass completion fish | source
    end

    # guarded path extras / tooling present on this machine
    if test -f /home/linuxbrew/.linuxbrew/bin/brew
        set -gx HOMEBREW_PREFIX "/home/linuxbrew/.linuxbrew"
        set -gx HOMEBREW_CELLAR "/home/linuxbrew/.linuxbrew/Cellar"
        set -gx HOMEBREW_REPOSITORY "/home/linuxbrew/.linuxbrew/Homebrew"
        fish_add_path /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin
    end
    if type -q asdf
        set -gx ASDF_DIR (brew --prefix asdf)/libexec
        fish_add_path "$ASDF_DIR/bin" ~/.asdf/shims
        . "$ASDF_DIR/asdf.fish"
    end
    if test -d /usr/pgadmin4/bin
        fish_add_path /usr/pgadmin4/bin
    end
    if test -d ~/library/apps/git-fuzzy
        fish_add_path ~/library/apps/git-fuzzy/bin
    end

    # grc color-wrapped commands
    if type -q grc
        for exe in cat cvs df diff dig gcc g++ ls ifconfig make mount mtr \
            netstat ping ps tail traceroute wdiff blkid du dnf docker \
            docker-machine env id ip iostat last lsattr lsblk lspci lsmod \
            lsof getfacl getsebool ulimit uptime nmap fdisk findmnt free \
            semanage sar ss sysctl systemctl stat showmount tcpdump tune2fs \
            vmstat w who
            if type -q $exe
                function $exe --inherit-variable exe --wraps=$exe
                    if isatty 1
                        grc $exe $argv
                    else
                        command $exe $argv
                    end
                end
            end
        end
    end
  '';

  # starship's fish init (`starship init fish | source`) is injected into
  # programs.fish.interactiveShellInit automatically via enableFishIntegration.
  programs.starship = {
    enable = true;
    package = pkgs.unstable.starship;
    enableFishIntegration = true;
    settings = {
      kubernetes.disabled = false;
      aws = {
        symbol = " ";
      };
      conda = {
        symbol = " ";
      };
      dart = {
        symbol = " ";
      };
      directory.read_only = " ";
      docker_context = {
        symbol = " ";
      };
      elixir = {
        symbol = " ";
      };
      elm = {
        symbol = " ";
      };
      git_branch = {
        symbol = " ";
      };
      golang = {
        symbol = " ";
      };
      hg_branch = {
        symbol = " ";
      };
      java = {
        symbol = " ";
      };
      julia = {
        symbol = " ";
      };
      memory_usage = {
        symbol = " ";
      };
      nim = {
        symbol = " ";
      };
      nix_shell = {
        symbol = " ";
      };
      nodejs = {
        symbol = " ";
        disabled = true;
      };
      package = {
        symbol = " ";
      };
      perl = {
        symbol = " ";
      };
      php = {
        symbol = " ";
      };
      python = {
        symbol = " ";
      };
      ruby = {
        symbol = " ";
      };
      rust = {
        symbol = " ";
      };
      swift = {
        symbol = "ﯣ ";
      };
    };
  };
}
