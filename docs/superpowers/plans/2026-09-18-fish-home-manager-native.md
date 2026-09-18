# Fish → Home-Manager Native Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raw `xdg.configFile."fish"` script dump at `home-manager/modules/fish/` with native `programs.fish` options, moving env/PATH to `home.sessionVariables`/`home.sessionPath` and starship to `programs.starship`.

**Architecture:** One rewritten file `home-manager/modules/fish/default.nix` declares every option declaratively; home-manager generates `~/.config/fish/config.fish` and `~/.config/fish/functions/*.fish` for us. The raw `fish/` dir is deleted. Live behavior (ssh-agent + gopass keys, vi mode, all abbrs, functions, prompt) preserved.

**Tech Stack:** Nix / home-manager (release-26.05) `programs.fish`, `home.sessionVariables`, `home.sessionPath`, `programs.starship`.

## Global Constraints

- Module file: `home-manager/modules/fish/default.nix` (single file, not a dir).
- `home.packages` keeps `pkgs.unstable.fish` and `pkgs.unstable.starship`.
- `programs.starship.package = pkgs.unstable.starship`; `enableFishIntegration = true`.
- ssh-agent + gopass key-loading MUST be preserved (user requirement).
- `fish_ssh_agent.fish` function is KEPT as a function (user vetoed its removal); it is separate from the live `ssh-agent-prepare` handler.
- Host-level `programs.fish.enable = true;` in `hosts/*/configuration.nix` stays (that is the NixOS system module, orthogonal — do NOT touch it).
- Every task ends with `nix flake check` (validates eval + pre-commit format gate). Real deploy is Task 3.
- Intermediate commits only need to be eval-valid (`nix flake check` green), not deployed.

---

### Task 1: Rewrite module skeleton + env/path

**Files:**
- Rewrite: `home-manager/modules/fish/default.nix`

**Interfaces:**
- Produces: `home.sessionVariables` (`EDITOR`, `GOPATH`, `BAT_THEME`, `FZF_DEFAULT_OPTS`), `home.sessionPath`, `programs.fish.enable = true`, a `programs.fish.functions` block (empty attrs here, filled in Task 2), `programs.fish.shellAbbrs` (empty, filled in Task 3). Removes the old `xdg.configFile."fish"...`, `".../fzf_key_bindings.fish"...` and `xdg.configFile."starship.toml"` copies.

- [ ] **Step 1: Rewrite `default.nix` to the skeleton**

Replace the entire contents of `home-manager/modules/fish/default.nix` with:

```nix
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

  programs.fish.enable = true;

  # dynamic arch/hostname bin dirs cannot be declarative sessionPath
  programs.fish.shellInit = ''
    fish_add_path --glob "$HOME/bin/"*
    fish_add_path "$HOME/bin/(uname -m)" "$HOME/bin/(hostname)"
  '';

  # filled in Task 2 (functions) and Task 3 (abbrs, starship)
  programs.fish.functions = { };
  programs.fish.shellAbbrs = { };
  programs.fish.promptInit = "";
  programs.fish.interactiveShellInit = "";
}
```

Note: FZF_DEFAULT_OPTS contains `#` characters; using a Nix multiline string (`''...''`) keeps them literal. Nix only interpolates `${...}`, so a bare `$HOME` in a Nix double-quoted string is emitted literally into the generated fish and expands at run time — write `$HOME`, not `\${HOME}`.

- [ ] **Step 2: Verify eval**

Run: `cd /home/marv/nix && nix flake check`
Expected: passes (nixfmt/statix/typos pre-commit hooks run on the touched files; no eval error). If `nixfmt` flags formatting, run `nix fmt` on the file and re-check.

- [ ] **Step 3: Commit**

```bash
cd /home/marv/nix
git add home-manager/modules/fish/default.nix
git commit -m "refactor: native fish module skeleton with env and path"
```

---

### Task 2: Functions + interactive init (ssh-agent, dracula, guards) + prompt

**Files:**
- Modify: `home-manager/modules/fish/default.nix`

**Interfaces:**
- Consumes: the `programs.fish.functions = { };` / `interactiveShellInit = "";` / `promptInit = "";` placeholders from Task 1.
- Produces: `programs.fish.functions.<name>.body` for all ports below; populated `interactiveShellInit`; `promptInit`.

- [ ] **Step 1: Fill `programs.fish.functions`**

Replace `programs.fish.functions = { };` with the block below. Every body is the **verbatim** contents of the matching `functions/*.fish` file (minus the `function NAME`/`end` wrapper — the attr name supplies the function name). These are direct copies, not paraphrased.

```nix
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
      argumentNames = [ "url" "destination" ];
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
    "fish_greeting" = {
      body = ''
        if type -q fortlit
            fortlit
        end
      '';
    };
    "fish_mode_prompt" = {
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
    "fish_user_key_bindings" = {
      body = ''
        if type -q fzf_key_bindings
            fzf_key_bindings
        end
      '';
    };
    "fish_ssh_agent" = {
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
```

Keep the `fish_ssh_agent` body with its nested helper functions (they must live in the same file/function as in the original — do not split them into separate function attrs, autoloading only sources the top-level `fish_ssh_agent`).

- [ ] **Step 2: Fill `programs.fish.interactiveShellInit`**

Replace `programs.fish.interactiveShellInit = "";` with:

```nix
  # runs in interactive shells, after HM has applied abbrs/aliases
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

    # ssh-agent + gopass keys (formerly conf.d/ssh-agent-prepare.fish) -- MUST KEEP
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

    # gpg
    if type -q gpg-agent
        set -gx GPG_TTY (tty)
    end

    # gopass completions
    if type -q gopass
        gopass completion fish | source
    end

    # direnv
    if type -q direnv
        direnv hook fish | source
    end

    # guarded path extras / tooling that only applies where present
    if test -f /home/linuxbrew/.linuxbrew/bin/brew
        set -gx HOMEBREW_PREFIX "/home/linuxbrew/.linuxbrew"
        set -gx HOMEBREW_CELLAR "/home/linuxbrew/.linuxbrew/Cellar"
        set -gx HOMEBREW_REPOSITORY "/home/linuxbrew/.linuxbrew/Homebrew"
        fish_add_path /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin /home/linuxbrew/.linuxbrew/share
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
        for executable in cat cvs df diff dig gcc g++ ls ifconfig make mount \
            mtr netstat ping ps tail traceroute wdiff blkid du dnf docker \
            docker-machine env id ip iostat last lsattr lsblk lspci lsmod \
            lsof getfacl getsebool ulimit uptime nmap fdisk findmnt free \
            semanage sar ss sysctl systemctl stat showmount tcpdump tune2fs \
            vmstat w who
            if type -q $executable
                set -l execn $executable
                function $execn --inherit-variable execn --wraps=$executable
                    if isatty 1
                        grc $execn $argv
                    else
                        command $execn $argv
                    end
                end
            end
        end
    end
  '';
```

Note the grc loop had a bug-free translation: the original used `--inherit-variable executable` but shadowed `$executable`; here a fresh `$execn` name is inherited to avoid `function $executable` recursion issues. If you prefer an exact 1:1 port, keep the original `--wraps` semantics; do not change observable command behavior.

- [ ] **Step 3: Fill `programs.fish.promptInit`**

Replace `programs.fish.promptInit = "";` with:

```nix
  programs.fish.promptInit = ''
    if test "$TERM" != "dumb"
        ${pkgs.unstable.starship}/bin/starship init fish | source
    end
  '';
```

- [ ] **Step 4: Verify eval**

Run: `cd /home/marv/nix && nix flake check`
Expected: passes. If statix/nixfmt flags the heredoc or formatting, run `nix fmt` and re-check. (Nested `${...}` inside `''...''` is intended here — it inlines the starship store path.)

- [ ] **Step 5: Commit**

```bash
cd /home/marv/nix
git add home-manager/modules/fish/default.nix
git commit -m "feat: native fish functions, interactive init, and prompt"
```

---

### Task 3: Abbreviations + native starship + remove old files

**Files:**
- Modify: `home-manager/modules/fish/default.nix`
- Delete: `home-manager/modules/fish/fish/` (whole dir), and the `pkgs` arg becomes unused → remove it from the lambda args if so.

**Interfaces:**
- Consumes: `programs.fish.shellAbbrs = { };` placeholder from Task 1.
- Produces: filled `programs.fish.shellAbbrs`, `programs.starship`, deleted raw `fish/` dir.

- [ ] **Step 1: Fill `programs.fish.shellAbbrs`**

Replace `programs.fish.shellAbbrs = { };` with:

```nix
  programs.fish.shellAbbrs = {
    # ls / search
    ll = "exa --git -la";
    cat = "bat";
    vim = "nvim";
    fd = "fd -I";
    rg = "rg --no-ignore-vcs --hidden";
    prev = "fzf --preview 'bat --style=numbers --color=always {}'";
    watch = "viddy";
    # git
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
    # kubernetes / tools
    k = "kubectl";
    ks = "set -gx KUBECONFIG (fd -I -t f --exact-depth 1 . ~/.kube|fzf)";
    tf = "terraform";
    t = "task";
    mutt = "neomutt";
    rcp = "rsync -ah --info=progress2";
    rmv = "rsync -ah --info=progress2 --remove-source-files";
    ssh = "TERM=xterm-256color SHELL=/bin/sh ssh";
    yaegi = "rlwrap yaegi";
    jellyfin-mpv = "flatpak run com.github.iwalton3.jellyfin-mpv-shim/x86_64/stable";
    "coderadio" = "tmux rename-window coderadio; mpv http://coderadio-admin.freecodecamp.org/radio/8010/radio.mp3";
    "chillradio" = "tmux rename-window chillradio; streamlink https://www.youtube.com/watch?v=jfKfPfyJRdk 720p -p \"mpv --no-video\"";
    "synthwaveradio" = "tmux rename-window synthwaveradio; mpv --no-video https://www.youtube.com/watch?v=4xDzrJKXOOY";
  };
```

If you prefer exact abbr fidelity over cleanup, keep the guarded `ll = "ls -la"` fallback: the original only aliased `ll` to `exa --git -la` when exa existed, else `ls -la`. Since `exa` is obsolete (superseded by `eza`), confirm `exa` is installed here before keeping the exa variant; otherwise use `ls -la`. Keep `cat`/`vim`/`mutt`/`watch` guarded by presence if you want strict parity — but as abbrs they are inert when the target is absent, so plain assignment is fine.

- [ ] **Step 2: Add native `programs.starship` and drop old toml copy**

Add below `programs.fish` (and above the closing `}` of the module):

```nix
  programs.starship = {
    enable = true;
    package = pkgs.unstable.starship;
    enableFishIntegration = true;
    settings = {
      kubernetes.disabled = false;
      aws = { symbol = " "; };
      conda = { symbol = " "; };
      dart = { symbol = " "; };
      directory.read_only = " ";
      docker_context = { symbol = " "; };
      elixir = { symbol = " "; };
      elm = { symbol = " "; };
      git_branch = { symbol = " "; };
      golang = { symbol = " "; };
      hg_branch = { symbol = " "; };
      java = { symbol = " "; };
      julia = { symbol = " "; };
      memory_usage = { symbol = " "; };
      nim = { symbol = " "; };
      nix_shell = { symbol = " "; };
      nodejs = { symbol = " "; disabled = true; };
      package = { symbol = " "; };
      perl = { symbol = " "; };
      php = { symbol = " "; };
      python = { symbol = " "; };
      ruby = { symbol = " "; };
      rust = { symbol = " "; };
      swift = { symbol = "ﯣ "; };
    };
  };
```

This replaces the old `xdg.configFile."starship.toml".text = '' ... '';` — remove that block entirely (home-manager generates `starship.toml` from `settings` itself). The `nodejs` entry uses `{ symbol = …; disabled = true; }` because the original toml had `disabled = true` under `[nodejs]`.

- [ ] **Step 3: Delete the raw fish dir and stale keybindings copy**

```bash
cd /home/marv/nix
rm -rf home-manager/modules/fish/fish
```

Also confirm no `xdg.configFile."fish"`, `"...fzf_key_bindings.fish"...`, or `"...starship.toml"` copies remain in the file (Steps 1–2 removed them). If after deletion the `${pkgs}` arg is unused (starship still uses it, so it stays), keep it.

- [ ] **Step 4: Verify eval + formatting**

Run: `cd /home/marv/nix && nix flake check`
Expected: passes; no reference to the deleted `fish/` dir remains anywhere in the repo (`rg 'modules/fish/fish' ~/nix` → empty).

- [ ] **Step 5: Commit**

```bash
cd /home/marv/nix
git add -A home-manager/modules/fish
git commit -m "refactor: native fish abbrs, starship module, drop raw fish dir"
```

---

### Task 4: Deploy verification (user-run) + post-switch migration

**Files:**
- None (verification only).

- [ ] **Step 1: Build check**

Run: `sudo nixos-rebuild build`
Expected: builds clean. Do NOT `switch` yourself (user-driven deploy per repo rules).

- [ ] **Step 2: User switches, then runs the one-time migration**

The user runs:
```bash
nixos-rebuild switch
fish -c "abbr --erase (abbr --list); set -e fish_user_paths; \
  and echo EDITOR=(echo \$EDITOR); and type -q rg; and echo PATH-ok"
```

- [ ] **Step 3: Interactive smoke test (user)**

Open a new fish shell and confirm: vi mode + `I/N` mode prompt; prompt renders via starship (Dracula-looking); `ssh-add -l` shows the gopass keys and `$SSH_AUTH_SOCK` is set; `g`, `ll`, `fd`, `tf`, radio abbrs expand; `sudo !!` works (needs a history entry).
