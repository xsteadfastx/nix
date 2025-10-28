{
  nixosConfig,
  lib,
  pkgsUnstable,
  ...
}:
let
  cfg = nixosConfig.xsfx;
in
lib.mkIf cfg.x11 {
  programs.firefox = {
    enable = true;
    policies = {
      DefaultDownloadDirectory = "~/tmp";
      DisableAccounts = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "never";
      DontCheckDefaultBrowser = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      FirefoxHome = {
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        SponsoredTopSites = false;
        TopSites = false;
      };
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      Preferences = {
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.system.showSponsored" = false;
        "browser.topsites.contile.enabled" = false;
        "extensions.pocket.enabled" = false;
      };
    };
    profiles.default = {
      settings = {
        "browser.aboutConfig.showWarning" = false;
        "browser.compactmode.show" = true;
        "extensions.autoDisableScopes" = 0;
        "signon.rememberSignons" = false;
      };
      extensions.packages = with pkgsUnstable.firefox-addons; [
        darkreader
        dracula-dark-colorscheme
        greasemonkey
        i-dont-care-about-cookies
        ublock-origin
        vimium
      ];
    };
  };
}
