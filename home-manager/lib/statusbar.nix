# The one description of the desktop bar's metrics.
#
# wayle draws cpu, memory, disk, battery and clock from here -- glyph, colour,
# battery icons -- see home-manager/modules/wayle.nix. zellij's bar borrows only
# the clock glyph (home-manager/modules/zellij/default.nix).
#
# `color` is a Catppuccin colour name (lib/palette.nix); wayle resolves it as
# `@<name>` from the port's @define-color file.
{ lib }:
let
  # Glyph codepoints are written as hex strings: nixfmt (1.5.0) rewrites a
  # `0x..` literal as `0 x..`, which no longer parses.
  glyph = lib.fromHexString;

  # A glyph is stored as a codepoint, and both forms the bars need are derived
  # from it. JSON's \u takes exactly four hex digits, so codepoints above
  # U+FFFF -- most of the Material Design set -- have to be written as a UTF-16
  # surrogate pair; hand-writing those is how a glyph once silently turned into
  # an empty string.
  # ponytail: no codepoint->char in nixpkgs lib (charToInt only, checked on
  # master), and literal glyphs would lose the codepoints the fc-query note
  # depends on. Leave it.
  hex4 = n: lib.fixedWidthString 4 "0" (lib.toUpper (lib.toHexString n));
  jsonEscape =
    cp:
    if cp < 65536 then # 0x10000
      "\\u${hex4 cp}"
    else
      let
        n = cp - 65536; # 0x10000
      in
      # 55296 = 0xD800, 56320 = 0xDC00 (the UTF-16 surrogate bases)
      "\\u${hex4 (55296 + n / 1024)}\\u${hex4 (56320 + lib.mod n 1024)}";

  # Glyphs for the metrics below. A bar with segments of its own keeps their
  # glyphs in its own module.
  #
  # Every codepoint here was checked against the built font's charset
  # (fc-query / fontTools cmap) of pkgs/jetbrains-mono-nerd -- the
  # Font Awesome and Material ranges are there.
  icons = {
    cpu = glyph "F2DB"; # fa-microchip
    # fa-memory (EFC5) is a DIMM stick; md-memory (F035B), the obvious pick, is a
    # second square chip with pins -- indistinguishable from fa-microchip at 15px.
    memory = glyph "EFC5"; # fa-memory
    disk = glyph "F02CA"; # md-harddisk
    clock = glyph "F0954"; # md-clock

    # fa-battery-empty / quarter / half / three-quarters / full, in the order
    # both bars step through them by charge level.
    batteryEmpty = glyph "F244";
    batteryQuarter = glyph "F243";
    batteryHalf = glyph "F242";
    batteryThreeQuarters = glyph "F241";
    batteryFull = glyph "F240";
  };

  # `color` is a Catppuccin colour name.
  segments = {
    cpu = {
      glyph = icons.cpu;
      color = "peach";
    };
    memory = {
      glyph = icons.memory;
      color = "sky";
    };
    disk = {
      glyph = icons.disk;
      color = "green";
    };
    battery = {
      color = "pink";
      # No single glyph: the bars step through these by charge level.
      icons = [
        icons.batteryEmpty
        icons.batteryQuarter
        icons.batteryHalf
        icons.batteryThreeQuarters
        icons.batteryFull
      ];
      states = [
        {
          name = "warning";
          color = "yellow";
        }
        {
          name = "critical";
          color = "red";
        }
      ];
    };
    clock = {
      glyph = icons.clock;
      color = "overlay1";
    };
  };
in
rec {
  inherit
    icons
    segments
    jsonEscape
    ;

  # The glyph itself, decoded back out of its JSON escape -- for the places
  # that want the character rather than a JSON string literal (the zjstatus
  # layout and the shell script).
  char = cp: builtins.fromJSON ''"${jsonEscape cp}"'';

  # One state by name (zellij's battery warning/critical colours).
  stateOf = segment: name: lib.findFirst (state: state.name == name) null segments.${segment}.states;
}
