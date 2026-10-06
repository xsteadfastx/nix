# The one description of the metrics *both* bars show.
#
# waybar (wayland) and zellij's zjstatus bar both carry cpu, memory, disk,
# battery and clock, and are meant to read identically: same glyph, same colour,
# same warning/critical thresholds. Those values live here, once; each bar
# renders them into its own dialect:
#
#   waybar    config JSON (icons, states, format-icons) and the generated part
#             of style.css (@define-color palette, the metric colour/state
#             rules) -- see home-manager/modules/waybar/default.nix
#   zjstatus  the layout's color_* vars and command_*_format strings, and the
#             zellij-statusbar-metrics shell script (glyphs, thresholds, and the
#             SGR it prints for a warning/critical value) -- see
#             home-manager/modules/zellij/default.nix
#
# A bar with segments of its own keeps them entirely in its own module: not
# every waybar module has a zjstatus counterpart (network, volume, mpris), and
# nothing but the five metrics above is shared.
#
# So "the two bars disagree" is impossible by construction rather than by two
# comments asking the next reader to keep them in sync. Adding a metric means one
# entry in `segments` here and one consumer-side line for it; the values each
# consumer needs (glyph, colour, thresholds) are already in the entry.
#
# Colours are the Dracula palette, checked against the spec
# (spec.draculatheme.com, 1.2.1 Standard) -- all eleven values match it. The
# spec's ANSI set (1.2.2: AnsiBlack #21222c, AnsiBrightRed #ff6e6e, ...) is
# deliberately not here: nothing in these two bars uses it, and an unused
# colour is one more thing to keep in sync. Add an entry when a consumer
# needs one, the same as any other colour.
{ lib }:
let
  # Glyph codepoints are written as hex strings: nixfmt (1.5.0) rewrites a
  # `0x..` literal as `0 x..`, which no longer parses.
  glyph = lib.fromHexString;

  # A glyph is stored as a codepoint, and both forms the bars need are derived
  # from it. JSON's \u takes exactly four hex digits, so codepoints above
  # U+FFFF -- most of the Material Design set -- have to be written as a UTF-16
  # surrogate pair; hand-writing those is how a glyph once silently turned into
  # an empty string and waybar got `format: ""`.
  # ponytail: this is the pure-Nix way to get from a codepoint back to a
  # character -- there is no lib helper for it (nixpkgs lib has `charToInt`,
  # nothing in the other direction, checked on master). The only alternative is
  # writing the glyphs literally, which loses the codepoints the fc-query note
  # below depends on. Leave it.
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

  # "#50fa7b" -> [ 80 250 123 ]: the three channels of a palette colour. Both
  # consumers that need numbers rather than hex (zellij's theme, which takes
  # `r g b`, and the SGR the metrics script prints) are built on this.
  rgb =
    hex:
    let
      n = lib.fromHexString (lib.removePrefix "#" hex);
    in
    [
      (n / 65536)
      (lib.mod (n / 256) 256)
      (lib.mod n 256)
    ];

  # "#50fa7b" -> "38;2;80;250;123": the SGR parameters for a palette colour.
  # zjstatus parses `#[fg=...]` only in the format string it is handed
  # (src/render.rs `from_format_string`), never in a command's stdout, so a
  # command that has to change colour on its own prints the raw SGR instead.
  sgr = hex: "38;2;" + lib.concatStringsSep ";" (map toString (rgb hex));

  # Glyphs for the metrics below -- the segments *both* bars carry. A bar with
  # segments of its own keeps their glyphs in its own module (waybar's network,
  # volume and mpris icons live in home-manager/modules/waybar/default.nix).
  #
  # Every codepoint here was checked against the built font's charset
  # (fc-query), which is why the icons work at all: this font only gained the
  # Font Awesome / Material ranges once `--complete` was passed to
  # font-patcher (see pkgs/jetbrainsmono-nerdfont-zero.nix).
  icons = {
    cpu = glyph "F2DB"; # fa-microchip
    memory = glyph "F035B"; # md-memory
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

  # The metrics on both bars. `waybar` / `zjstatus` are the names each side
  # knows the segment by; `color` is a palette key; `states` are the
  # warning/critical steps each side renders (waybar as CSS classes, the shell
  # script as SGR).
  segments = {
    cpu = {
      waybar = "cpu";
      zjstatus = "command_cpu";
      glyph = icons.cpu;
      color = "orange";
    };
    memory = {
      waybar = "memory";
      zjstatus = "command_ram";
      glyph = icons.memory;
      color = "cyan";
    };
    disk = {
      waybar = "disk";
      zjstatus = "command_disk";
      glyph = icons.disk;
      color = "green";
      # Order is the order both bars paint them in (waybar's CSS classes,
      # the shell script's SGR); an attrset would sort them.
      states = [
        {
          name = "warning";
          at = 80;
          color = "yellow";
        }
        {
          name = "critical";
          at = 90;
          color = "red";
        }
      ];
    };
    battery = {
      waybar = "battery";
      zjstatus = "command_battery";
      color = "pink";
      # The word both bars print while the machine is on mains but not topped
      # off, and which waybar classes count as that (waybar puts the sysfs
      # status on the module lowercased -- `not-charging` -- and swaps its whole
      # format per class, so it repeats the word per class rather than having a
      # placeholder for it). Nothing is printed while discharging or full.
      word = "AC";
      wordClasses = [
        "charging"
        "not-charging"
        "plugged"
        "unknown"
      ];
      # No single glyph: both bars step through these by charge level.
      icons = [
        icons.batteryEmpty
        icons.batteryQuarter
        icons.batteryHalf
        icons.batteryThreeQuarters
        icons.batteryFull
      ];
      states = [
        # Charge, so the comparison is the other way round from disk's:
        # waybar's battery module is the one module that passes
        # `lesser = true` to getState.
        {
          name = "warning";
          at = 30;
          color = "yellow";
          lesser = true;
        }
        {
          name = "critical";
          at = 15;
          color = "red";
          lesser = true;
        }
        # Not thresholds: waybar puts one of these classes on the module from
        # the battery status instead. Last, so a plugged-in battery reads
        # green even when it is also low -- the order the Dracula port's CSS
        # gives them.
        {
          name = "charging";
          classes = [
            "charging"
            "plugged"
          ];
          color = "green";
        }
        {
          name = "full";
          classes = [ "full" ];
          color = "green";
        }
      ];
    };
    clock = {
      waybar = "clock";
      zjstatus = "datetime";
      glyph = icons.clock;
      color = "comment";
    };
  };
in
rec {
  # dracula/waybar's colors.css, verbatim: the eleven spec colours plus the
  # port's own translucent bar surface. `background-darker` is the one entry
  # the spec (1.2.1 Standard) does not have -- the spec's ANSI set lists
  # #21222c as AnsiBlack, an opaque shade the notification centre uses -- but
  # this is the port the bar takes its colours from, so it stays with them.
  palette = {
    background-darker = "rgba(30, 31, 41, 230)";
    background = "#282a36";
    selection = "#44475a";
    foreground = "#f8f8f2";
    comment = "#6272a4";
    cyan = "#8be9fd";
    green = "#50fa7b";
    orange = "#ffb86c";
    pink = "#ff79c6";
    purple = "#bd93f9";
    red = "#ff5555";
    yellow = "#f1fa8c";
  };

  inherit
    icons
    segments
    jsonEscape
    rgb
    sgr
    ;

  # The glyph itself, decoded back out of its JSON escape -- for the places
  # that want the character rather than a JSON string literal (the zjstatus
  # layout and the shell script).
  char = cp: builtins.fromJSON ''"${jsonEscape cp}"'';

  # `states` as waybar's modules want it: name -> threshold, thresholds only
  # (status-derived ones like battery.charging have no number).
  statesFor =
    name:
    lib.listToAttrs (
      map (state: lib.nameValuePair state.name state.at) (
        lib.filter (state: state ? at) (segments.${name}.states or [ ])
      )
    );

  # One state by name, for consumers that render just one of them (the shell
  # script's warning/critical steps).
  stateOf = segment: name: lib.findFirst (state: state.name == name) null segments.${segment}.states;
}
