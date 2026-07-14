{ pkgs, ... }:
{
  home.packages = [
    pkgs.tmux
    pkgs.tmux-xpanes
    # tmux wrapper: persistent "local" anchor session survives Ghostty crashes;
    # each window gets its own grouped view that auto-destroys when detached,
    # so closing a Ghostty leaves no zombie sessions behind.
    (pkgs.writeShellScriptBin "tmx" ''
      set -e

      ${pkgs.tmux}/bin/tmux has-session -t local 2>/dev/null \
        || ${pkgs.tmux}/bin/tmux new-session -d -s local
      exec ${pkgs.tmux}/bin/tmux new-session -t local \; set-option destroy-unattached on
    '')
  ];

  home.file.".tmux.conf".text = ''
    unbind C-b
    set -g prefix C-a
    bind C-a send-prefix

    # enable extended keys for better compatibility with terminal emulators
    set -g extended-keys on
    set -g extended-keys-format csi-u

    # start window numbering at 1 for easier switching
    set -g base-index 1

    # colors
    # set -g default-terminal "alacritty"
    # set -g terminal-overrides ",alacritty:Tc"

    # listen to alerts from all windows
    set -g bell-action any
    set-hook -g alert-bell 'set -g pane-active-border-style "fg=red"; run-shell "sleep 0.2"; set -g pane-active-border-style "fg=#bd93f9"'

    # rebind pane tiling
    bind v split-window -h
    bind H split-window

    # vim movement bindings
    set-window-option -g mode-keys vi
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R
    unbind Left
    unbind Down
    unbind Up
    unbind Right

    # default window name
    # bind-key c new-window -n "$"

    # reload config
    unbind r
    # bind r source-file ~/.tmux.conf

    # use fish shell
    set-option -g default-shell ${pkgs.unstable.fish}/bin/fish

    # mouse
    set -g mouse on

    # escape time
    set-option -sg escape-time 10

    # resize
    set-window-option -g aggressive-resize on

    # needed by nvim
    set-option -g focus-events on

    # dracula
    set -g @dracula-plugins "battery cpu-usage ram-usage time"
    set -g @dracula-show-powerline true
    set -g @dracula-day-month true
    set -g @dracula-show-timezone false
    set -g @dracula-show-left-icon "🐧"
    set -g @dracula-cpu-usage-label ""
    set -g @dracula-ram-usage-label ""

    run ~/.tmux-dracula/dracula.sh

    # better visibility on bell alerts
    # set-option -g window-status-separator ""
    # set-window-option -g window-status-format "#[fg=#44475a,bg=#{?window_bell_flag,#ff5555,#44475a}]#[fg=#{?window_bell_flag,#282a36,#f8f8f2},bg=#{?window_bell_flag,#ff5555,#44475a},#{?window_bell_flag,bold,none}] #I #W#{?window_flags,#{window_flags}, }#[fg=#{?window_bell_flag,#ff5555,#44475a},bg=#44475a]"
    # set-window-option -g window-status-current-format "#[fg=#44475a,bg=#bd93f9]#[fg=#282a36,bg=#bd93f9,bold] #I #W#{?window_flags,#{window_flags}, }#[fg=#bd93f9,bg=#44475a]"

    set-option -g status-style "bg=#44475a,fg=#f8f8f2"
    set-option -g window-status-separator ""
    set-window-option -g window-status-format "#[fg=#44475a,bg=#{?window_bell_flag,#ff5555,#6272a4}]#[fg=#{?window_bell_flag,#282a36,#f8f8f2},bg=#{?window_bell_flag,#ff5555,#6272a4},#{?window_bell_flag,bold,none}] #I #W #[fg=#{?window_bell_flag,#ff5555,#6272a4},bg=#44475a]"
    set-window-option -g window-status-current-format "#[fg=#44475a,bg=#bd93f9]#[fg=#282a36,bg=#bd93f9,bold] #I #W #[fg=#bd93f9,bg=#44475a]"
  '';

  home.file.".tmux-dracula" = {
    source = ./.tmux-dracula;
    recursive = true;
  };
}
