{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
  # The launcher/menu (replaced rofi). Wayland-native layer-shell, like the
  # rest of the session.
  #
  # wofi has only three modes -- run, drun, dmenu -- but combi exists as
  # `--show mode1,mode2`; the sway bindings in ../sway/config.nix reference it
  # by store path, so keep this package attr and the pin there identical.
  programs.wofi = {
    enable = true;
    package = pkgs.unstable.wofi;

    settings = {
      # Mirrors the old rofi theme (show-icons, no scrollbar).
      allow_images = true;
      hide_scroll = true;
      # rofi's dmenu/combi matched case-insensitively by default and wofi does
      # not -- the gopass binding is useless without this (store has mixed-case
      # entries like CGI/account-informationen). wofi's matching default is
      # `contains`, the same substring behaviour rofi's `normal` had.
      insensitive = true;
      # shift-enter in run mode opens the entry in a terminal
      terminal = "${pkgs.unstable.ghostty}/bin/ghostty";
    };

    # Official Dracula theme (github.com/dracula/wofi), font set to match the
    # rest of the session (the old rasi used JetBrainsMono Nerd Font 14).
    style = ''
      * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 14px;
      }

      window {
          margin: 0px;
          border: 1px solid #bd93f9;
          background-color: #282a36;
      }

      #input {
          margin: 5px;
          border: none;
          color: #f8f8f2;
          background-color: #44475a;
      }

      #inner-box {
          margin: 5px;
          border: none;
          background-color: #282a36;
      }

      #outer-box {
          margin: 5px;
          border: none;
          background-color: #282a36;
      }

      #scroll {
          margin: 0px;
          border: none;
      }

      #text {
          margin: 5px;
          border: none;
          color: #f8f8f2;
      }

      # Upstream Dracula also ships
      #   #entry.activatable #text { color: #282a36; }
      # which wofi only ever applies to the child rows inside a drun expander
      # (those are GtkListBoxRows and get .activatable; the top-level
      # GtkFlowBoxChild entries never do) -- so it just renders those children
      # in the background colour, i.e. invisible. Dropped; do not re-add.
      #entry > * {
          color: #f8f8f2;
      }

      #entry:selected {
          background-color: #44475a;
      }

      #entry:selected #text {
          font-weight: bold;
      }
    '';
  };
}
