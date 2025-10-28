{ pkgs, pkgsUnstable, ... }:
{
  home.packages = [
    pkgs.tmux
    # tmux wrapper for always same session
    (pkgs.writeShellScriptBin "tmx" ''
      set -e

      ${pkgs.tmux}/bin/tmux new-session -t local
    '')
  ];

  home.file.".tmux.conf".text = ''
    unbind C-b
    set -g prefix C-a
    bind C-a send-prefix

    # start window numbering at 1 for easier switching
    set -g base-index 1

    # colors
    # set -g default-terminal "alacritty"
    # set -g terminal-overrides ",alacritty:Tc"

    # listen to alerts from all windows
    set -g bell-action any

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
    set-option -g default-shell ${pkgsUnstable.fish}/bin/fish

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
  '';

  home.file.".tmux-dracula" = {
    source = ./.tmux-dracula;
    recursive = true;
  };
}
