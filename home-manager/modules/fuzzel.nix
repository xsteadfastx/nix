{
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;

  # md-magnify, U+F0349 (checked against the built font's charset). Literal,
  # because Nix has no codepoint -> char builtin.
  searchGlyph = "󰍉";
in
lib.mkIf cfg.desktop {
  # The launcher and dmenu (replaced wofi). Mod+D, the gopass picker and the
  # window switcher in ../niri call it by store path, so keep this package attr
  # and those identical.
  programs.fuzzel = {
    enable = true;
    package = pkgs.unstable.fuzzel;

    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=16";
        # NBSP, not spaces: the ini parser strips trailing whitespace, so a
        # plain "  " collapses and the glyph ends up glued to the input.
        prompt = "${searchGlyph}  ";
        # Same pixel size everywhere. With all outputs at scale 1, `auto` sizes
        # by the monitor's reported DPI, and the TV (1000x610 mm at 1360x768,
        # ~35 DPI) shrank the text to ~5 px.
        dpi-aware = "no";
        terminal = "${pkgs.unstable.ghostty}/bin/ghostty -e";
        list-executables-in-path = false;
        launch-prefix = "${pkgs.unstable.app2unit}/bin/app2unit --";

        # Room to breathe. Defaults are 30 chars / 15 lines / 40 px side padding
        # / 0 px between prompt and list; 15 lines is taller than the screen is
        # worth and 40 px of dead air reads odd in a flat, 1 px bordered window.
        width = 48;
        lines = 12;
        horizontal-pad = 24;
        vertical-pad = 20;
        inner-pad = 12;
        line-height = 22;

        # Spotlight instead of a strip: centred on the focused output, above
        # normal windows, with the app icons from the theme GTK already uses.
        anchor = "center";
        layer = "overlay";
        icons-enabled = "yes";
        icon-theme = "Papirus-Dark";

        # fzf-style subsequence matching, so "chrom" finds "Google Chrome".
        match-mode = "fzf";
      };

      # The gopass pipes read one line and nothing else, so no icons and no
      # "keep this on Enter" behaviour there.
      dmenu = {
        mode = "text";
        exit-immediately-if-empty = "yes";
      };

      # Colours come from catppuccin.fuzzel (`main.include`).

      # Rounded accent border; the colour comes from catppuccin.fuzzel (mauve).
      border = {
        width = 2;
        radius = 12;
      };
    };
  };
}
