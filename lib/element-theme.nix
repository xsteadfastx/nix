# Dracula for Element, as a custom theme. Shared by both Element instances so
# they cannot drift: the homeserver's web client (hosts/dipper/matrix/default.nix,
# served at www.matrix.xsfx.dev) and Element Desktop on coltrane
# (home-manager/modules/matrix.nix). Consume it as
#
#   setting_defaults.custom_themes = [ (import ./lib/element-theme.nix) ];
#   default_theme = "custom-Dracula";   # internally the theme is custom-<name>
#
# Not an upstream theme: the only public Element Dracula theme
# (aaronraimist/element-themes, 2021) predates Compound and only sets legacy
# `colors` keys, which today's UI ignores. So this overrides Compound *semantic*
# tokens instead, using the canonical palette (draculatheme.com spec) --
# #282a36 background, #44475a current line, #f8f8f2 foreground, #6272a4 comment,
# #bd93f9 purple, plus the red/green/cyan accents. Element's stock dark theme is
# otherwise left alone, so hover/disabled states keep their intended contrast.
#
# Where an *intermediate* shade is unavoidable (hover, disabled, secondary text)
# it is a blend of two canonical colours and marked as such. Keys must match
# /^--cpd-[a-z0-9-]+$/ (apps/web/src/theme.ts) or Element drops them.
{
  name = "Dracula";
  is_dark = true;
  compound = {
    # Surfaces. #21222c is Dracula's darker background variant, used by most
    # ports for sidebars/panels.
    "--cpd-color-theme-bg" = "#282a36";
    "--cpd-color-bg-canvas-default" = "#282a36";
    "--cpd-color-bg-canvas-disabled" = "#21222c";
    "--cpd-color-bg-subtle-primary" = "#21222c"; # room list / side panel
    "--cpd-color-bg-subtle-secondary" = "#282a36";
    "--cpd-color-separator-primary" = "#44475a";
    "--cpd-color-separator-secondary" = "#383a4a"; # blend: #44475a -> #282a36

    # Rows and buttons. Selected room = Dracula's "current line".
    "--cpd-color-bg-action-tertiary-selected" = "#44475a";
    "--cpd-color-bg-action-tertiary-hovered" = "rgba(68, 71, 90, 0.6)";
    "--cpd-color-bg-action-secondary-rest" = "#282a36";
    "--cpd-color-bg-action-secondary-hovered" = "rgba(68, 71, 90, 0.6)";
    "--cpd-color-bg-action-secondary-pressed" = "rgba(68, 71, 90, 0.9)";
    "--cpd-color-bg-action-primary-rest" = "#bd93f9";
    "--cpd-color-bg-action-primary-hovered" = "#caa8fb"; # blend: purple -> foreground
    "--cpd-color-bg-action-primary-pressed" = "#a97ff5"; # blend: purple -> background
    "--cpd-color-bg-action-primary-disabled" = "#44475a";
    "--cpd-color-text-on-solid-primary" = "#282a36";

    # Accent.
    "--cpd-color-bg-accent-rest" = "#bd93f9";
    "--cpd-color-bg-accent-hovered" = "#caa8fb"; # blend
    "--cpd-color-text-action-accent" = "#bd93f9";
    "--cpd-color-border-accent-primary" = "#bd93f9";
    "--cpd-color-border-focused" = "#bd93f9";
    "--cpd-color-icon-accent-primary" = "#bd93f9";
    "--cpd-color-icon-accent-tertiary" = "#ff79c6";

    # Text. Secondary is a blend of comment (#6272a4, only 3.0:1 here) towards the
    # foreground, because Element uses it for body-adjacent metadata.
    "--cpd-color-text-primary" = "#f8f8f2";
    "--cpd-color-text-secondary" = "#8b9bc4"; # blend, 5.1:1 on #282a36
    "--cpd-color-text-disabled" = "#6272a4";
    "--cpd-color-text-action-primary" = "#f8f8f2";
    "--cpd-color-text-link-external" = "#8be9fd";
    "--cpd-color-icon-primary" = "#f8f8f2";
    "--cpd-color-icon-secondary" = "#8b9bc4"; # blend

    # Borders.
    "--cpd-color-border-interactive-primary" = "#44475a";
    "--cpd-color-border-interactive-secondary" = "#383a4a"; # blend
    "--cpd-color-border-interactive-hovered" = "#6272a4";
    "--cpd-color-border-disabled" = "#2f3140"; # blend: current line -> background

    # Badges.
    "--cpd-color-bg-badge-accent" = "#44475a";
    "--cpd-color-text-badge-accent" = "#bd93f9";
    "--cpd-color-bg-badge-primary" = "#f8f8f2";
    "--cpd-color-bg-badge-secondary" = "#44475a";

    # Status colours, straight from the palette.
    "--cpd-color-text-success-primary" = "#50fa7b";
    "--cpd-color-icon-success-primary" = "#50fa7b";
    "--cpd-color-text-critical-primary" = "#ff5555";
    "--cpd-color-icon-critical-primary" = "#ff5555";
    "--cpd-color-bg-critical-primary" = "#ff5555";
    "--cpd-color-border-critical-primary" = "#ff5555";
    "--cpd-color-text-info-primary" = "#8be9fd";
    "--cpd-color-icon-info-primary" = "#8be9fd";

    # Avatars / decorative accents, in palette order.
    "--cpd-color-text-decorative-1" = "#50fa7b";
    "--cpd-color-text-decorative-2" = "#8be9fd";
    "--cpd-color-text-decorative-3" = "#ff79c6";
    "--cpd-color-text-decorative-4" = "#bd93f9";
    "--cpd-color-text-decorative-5" = "#ffb86c";
    "--cpd-color-text-decorative-6" = "#f1fa8c";

    # Alpha tints. Element uses these for hovers, the mention flash and the accent
    # (green) wash; stock they are white/alice-blue and green, so they read off-
    # palette otherwise. Same alphas as stock, base colour swapped.
    "--cpd-color-alpha-gray-100" = "rgba(248, 248, 242, 0.02)";
    "--cpd-color-alpha-gray-200" = "rgba(248, 248, 242, 0.04)";
    "--cpd-color-alpha-gray-300" = "rgba(248, 248, 242, 0.06)";
    "--cpd-color-alpha-gray-400" = "rgba(248, 248, 242, 0.1)";
    "--cpd-color-alpha-gray-500" = "rgba(248, 248, 242, 0.15)";
    "--cpd-color-alpha-gray-600" = "rgba(248, 248, 242, 0.2)";
    "--cpd-color-alpha-gray-700" = "rgba(248, 248, 242, 0.27)";
    "--cpd-color-alpha-gray-800" = "rgba(248, 248, 242, 0.41)";
    "--cpd-color-alpha-gray-900" = "rgba(248, 248, 242, 0.54)";
    "--cpd-color-alpha-gray-1000" = "rgba(248, 248, 242, 0.61)";
    "--cpd-color-alpha-gray-1100" = "rgba(248, 248, 242, 0.68)";
    "--cpd-color-alpha-gray-1200" = "rgba(248, 248, 242, 0.79)";
    "--cpd-color-alpha-gray-1300" = "rgba(248, 248, 242, 0.89)";
    "--cpd-color-alpha-gray-1400" = "rgba(248, 248, 242, 0.95)";
    "--cpd-color-alpha-green-100" = "#1b1730"; # accent wash, purple instead of green
    "--cpd-color-alpha-green-200" = "#1e1a35";
    "--cpd-color-alpha-green-300" = "#221c3d";
    "--cpd-color-alpha-green-400" = "#262043";
    "--cpd-color-alpha-green-500" = "#2d2450";
  };

  # Element's pre-Compound variables. When a custom theme is active it enables
  # theme-dark-custom.css, which styles parts of the app from these (with no
  # fallbacks), so leaving them unset means "invalid declaration" there. Element
  # sets each of these on <body> and derives -0pct/-15pct/-50pct variants itself.
  colors = {
    "timeline-background-color" = "#282a36";
    "timeline-text-color" = "#f8f8f2";
    "timeline-text-secondary-color" = "#8b9bc4"; # blend
    "timeline-highlights-color" = "#44475a";
    "roomlist-background-color" = "#21222c";
    "roomlist-text-color" = "#f8f8f2";
    "roomlist-text-secondary-color" = "#8b9bc4"; # blend
    "roomlist-highlights-color" = "#44475a";
    "roomlist-separator-color" = "#383a4a"; # blend
    "sidebar-color" = "#21222c";
    "secondary-hairline-color" = "#44475a";
    "primary-color" = "#bd93f9";
    "accent-color" = "#bd93f9";
    "accent-color-300" = "#35285c";
    "accent-color-400" = "#bd93f9";
    "accent-color-1000" = "#caa8fb"; # blend
    "username-color" = "#bd93f9";
  };
}
