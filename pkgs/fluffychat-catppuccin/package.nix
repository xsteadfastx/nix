{
  lib,
  writeText,
  fluffychat,
  paletteFile,
  flavor ? "mocha",
  fontFamily ? "Nerdwand Mono",
}:

# FluffyChat cannot be themed at runtime, so the scheme is compiled in:
#
# - `FluffyThemes.buildTheme` derives every colour from one seed
#   (`ColorScheme.fromSeed`), and upstream has no theme-file support yet
#   (krille-chan/fluffychat#3866). Only the accent colour can be chosen.
# - Material hardcodes `Roboto` as the text family, and Flutter has no
#   system-font API at all (krille-chan/fluffychat#188,
#   flutter/flutter#48381), so the fontconfig fallback is a lottery.
#
# `themes.patch` rewires the two call sites to the generated file below; nothing
# else is touched, and the patch fails loudly if upstream moves them.
let
  # Both palettes, straight from the catppuccin flake input: the configured
  # flavour for dark, Latte for light. Reading the JSON (not the built port)
  # keeps this evaluation-only, so an aarch64 host needs no aarch64 build.
  palettes = lib.importJSON paletteFile;

  flavors = {
    dark = if flavor == "latte" then "mocha" else flavor;
    light = "latte";
  };

  argb =
    mode: name:
    "0xFF${lib.toUpper (lib.removePrefix "#" palettes.${flavors.${mode}}.colors.${name}.hex)}";

  # A role whose value differs per brightness.
  role = name: "Color(dark ? ${argb "dark" name} : ${argb "light" name})";

  catppuccinTheme = writeText "catppuccin_theme.g.dart" ''
    // Generated from the Catppuccin palette by pkgs/fluffychat-catppuccin.
    // Do not edit; change the flavour in modules/catppuccin.nix instead.
    import 'package:material_ui/material_ui.dart';

    /// Spelled out because Material's typography ignores the system font.
    const String catppuccinFontFamily = '${fontFamily}';

    ColorScheme catppuccinScheme(Brightness brightness) {
      final bool dark = brightness == Brightness.dark;
      // fidelity keeps the accent recognisable inside the derived containers;
      // surfaces, text and outlines are then replaced with the palette's own.
      return ColorScheme.fromSeed(
        seedColor: ${role "mauve"},
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        primary: ${role "mauve"},
        onPrimary: ${role "crust"},
        // Own message bubbles, unread badges and a few icons: FluffyChat paints
        // these with primaryContainer, so it has to be a palette colour too --
        // left to fromSeed(fidelity) it came out olive.
        primaryContainer: ${role "mauve"},
        onPrimaryContainer: ${role "crust"},
        // Only used as the link colour inside own bubbles in light mode
        // (FluffyChat checks brightness in message.dart), so it has to contrast
        // with the mauve bubble, not repeat it.
        primaryFixed: ${role "base"},
        secondary: ${role "blue"},
        onSecondary: ${role "crust"},
        // Search field, selected room rows, elevated buttons.
        secondaryContainer: ${role "surface1"},
        onSecondaryContainer: ${role "text"},
        tertiary: ${role "pink"},
        onTertiary: ${role "crust"},
        // tertiaryContainer feeds secondaryBubbleColor; its on-colour is the
        // link colour inside own bubbles, which sit on mauve above.
        tertiaryContainer: ${role "surface1"},
        onTertiaryContainer: ${role "crust"},
        error: ${role "red"},
        onError: ${role "crust"},
        surface: ${role "base"},
        onSurface: ${role "text"},
        onSurfaceVariant: ${role "subtext0"},
        surfaceContainerLowest: ${role "crust"},
        surfaceContainerLow: ${role "mantle"},
        surfaceContainer: ${role "surface0"},
        surfaceContainerHigh: ${role "surface1"},
        surfaceContainerHighest: ${role "surface2"},
        outline: ${role "overlay0"},
        outlineVariant: ${role "surface1"},
        inverseSurface: ${role "text"},
        onInverseSurface: ${role "base"},
      );
    }
  '';
in
fluffychat.overrideAttrs (old: {
  # pname/version stay upstream's: the desktop item's `exec` and the app dir
  # under $out/app are derived from them.
  patches = (old.patches or [ ]) ++ [ ./themes.patch ];

  postPatch = (old.postPatch or "") + ''
    install -Dm644 ${catppuccinTheme} lib/config/catppuccin_theme.g.dart
  '';

  meta = (old.meta or { }) // {
    description = "${old.meta.description or "Matrix client"} (Catppuccin ${flavor}, patched theme)";
  };
})
