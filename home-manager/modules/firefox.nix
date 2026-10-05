{
  config,
  nixosConfig,
  lib,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
  programs.firefox = {
    enable = true;
    # home-manager 26.05 moved this default under XDG. Adopted 2026-10-05: the
    # profile was moved from ~/.mozilla/firefox to here at the same time (see
    # the commit message), and ~/.mozilla now only carries native-messaging-hosts.
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    policies = {
      DefaultDownloadDirectory = "\${home}/tmp";
      DisableFirefoxStudies = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "never";
      DontCheckDefaultBrowser = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      FirefoxHome = {
        # Only the search box on a new tab; every content section is off. Pocket
        # and SponsoredPocket are the legacy aliases for Stories and
        # SponsoredStories -- policies.sys.mjs sets the same two prefs for both
        # spellings -- so only one of each is needed.
        Search = true;
        Highlights = false;
        Stories = false;
        SponsoredStories = false;
        TopSites = false;
        SponsoredTopSites = false;
        Snippets = false;
        Weather = false;
        Widgets = {
          Enabled = false; # clock, stocks, sports, crossword, ...
        };
        Locked = true; # and stay off, whatever Nimbus later thinks
      };
      # Mozilla's own popups: add-on/feature recommendations, urlbar
      # interventions, "More from Mozilla", What's New, Firefox Labs.
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        MoreFromMozilla = false;
        WhatsNew = false;
        FirefoxLabs = false;
        Locked = true;
      };
      # What you type is never sent to the search engine for suggestions.
      SearchSuggestEnabled = false;
      # Mozilla's own suggestion stream (Wikipedia/website lookups + sponsored).
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        OnlineEnabled = false;
        Locked = true;
      };
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      Preferences = {
        # Trending searches have no policy yet, so this is the only place they
        # can be switched off. Everything else that used to be listed here is
        # already covered by the FirefoxHome policy above -- which sets and
        # locks the very same prefs (policies.sys.mjs, FirefoxHome handler) --
        # and the sections those other prefs belonged to are off and locked.
        "browser.urlbar.trending.featureGate" = false;
        "browser.urlbar.suggest.trending" = false;
      };
      # Add-ons through Firefox's own policy, not home-manager's
      # `profiles.<p>.extensions.packages`: that route installs *unsigned* xpis
      # and release Firefox refuses to load those (it only works with
      # firefox-esr). These come from AMO, so they are signed and self-updating.
      # `normal_installed` keeps them disableable in about:addons.
      ExtensionSettings =
        let
          amo = slug: {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
          };
        in
        {
          "addon@darkreader.org" = amo "darkreader";
          "{b743f56d-1cc1-4048-8ba6-f9c2ab7aa54d}" = amo "dracula-dark-colorscheme";
          # Violentmonkey, not Greasemonkey 4: the MusicBrainz script community
          # runs VM/TM, and GM4 dropped the sync GM_* APIs (GM_xmlhttpRequest)
          # that the importers rely on.
          "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = amo "violentmonkey";
          # The community fork (Guus), not AMO's "i-dont-care-about-cookies" —
          # that one is the Gen Digital/Avast-owned original.
          "idcac-pub@guus.ninja" = amo "istilldontcareaboutcookies";
          "uBlock0@raymondhill.net" = amo "ublock-origin";
          "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = amo "vimium-ff";
          # Superseded on this machine. Dropping a policy entry does *not*
          # uninstall an add-on — Firefox keeps it — so these two are what
          # actually removes the Greasemonkey and cookie add-on that an earlier
          # build installed.
          "{e4a8a97b-f2ed-450b-b12d-ee082ba24781}" = {
            installation_mode = "blocked";
          };
          "jid1-KKzOGWgsW3Ao4Q@jetpack" = {
            installation_mode = "blocked";
          };
        };
    };
    profiles.default = {
      settings = {
        "browser.aboutConfig.showWarning" = false;
        # Actually *use* compact density: 0=normal, 1=compact, 2=touch. No
        # browser.compactmode.show here: that only reveals the density toggle in
        # Settings, and this pref is re-applied from user.js every start, so the
        # toggle could never stick anyway. Mostly toolbarbutton/urlbar spacing --
        # the tabs and toolbar rows stay.
        "browser.uidensity" = 1;
        "signon.rememberSignons" = false;
        # Resume where you left off — clean quit, reboot (the session manager
        # sets resume_session_once on logout) and crash alike. 3 = "show my
        # windows and tabs from last time": SessionStartup then reports
        # RESUME_SESSION, which takes precedence over the crash path, so the
        # about:sessionrestore interstitial never appears. That is why
        # browser.sessionstore.resume_from_crash and max_resumed_crashes are
        # deliberately absent: both are only consulted when startup.page != 3.
        "browser.startup.page" = 3;
      };
    };
  };

  # MusicBrainz userscripts. Firefox gives no way to put a script into a
  # userscript manager's storage, so the set is declared here (the scripts
  # themselves install from upstream, and Violentmonkey keeps them updated via
  # their @updateURL). Open the generated page once and click them in:
  #
  #   file://~/.local/share/mb-userscripts/index.html
  #
  # Edit the list to change what you run.
  home.file.".local/share/mb-userscripts/index.html".text =
    let
      scripts = {
        # cover art
        "Enhanced Cover Art Uploads" =
          "https://github.com/ROpdebee/mb-userscripts/raw/dist/mb_enhanced_cover_art_uploads.user.js";
        "Display CAA image dimensions" =
          "https://github.com/ROpdebee/mb-userscripts/raw/dist/mb_caa_dimensions.user.js";
        "1200px CAA" = "https://github.com/murdos/musicbrainz-userscripts/raw/master/mb_1200px_caa.user.js";
        # discs and rips
        "Musicbrainz DiscIds Detector" =
          "https://raw.githubusercontent.com/murdos/musicbrainz-userscripts/dist/mb_discids_detector.user.js";
        "MB Auto Track Lengths from CD TOC" =
          "https://update.greasyfork.org/scripts/493916/MB%20Auto%20Track%20Lengths%20from%20CD%20TOC.user.js";
        "Set recording comments for a release" =
          "https://github.com/murdos/musicbrainz-userscripts/raw/master/set-recording-comments.user.js";
        # seeding releases
        "Import Bandcamp releases" =
          "https://github.com/murdos/musicbrainz-userscripts/raw/master/bandcamp_importer.user.js";
        "Import Discogs releases" =
          "https://github.com/murdos/musicbrainz-userscripts/raw/master/discogs_importer.user.js";
        "Import Qobuz releases" =
          "https://github.com/murdos/musicbrainz-userscripts/raw/master/qobuz_importer.user.js";
        "Import Deezer releases" =
          "https://github.com/murdos/musicbrainz-userscripts/raw/master/deezer_importer.user.js";
        # editing helpers
        "MusicBrainz UI enhancements" =
          "https://github.com/murdos/musicbrainz-userscripts/raw/master/mb_ui_enhancements.user.js";
        "Batch Query AcoustID" =
          "https://github.com/y-young/userscripts/raw/master/musicbrainz-batch-query-acoustid.user.js";
        "Display AcoustIDs and merge by AcoustID" =
          "https://github.com/loujine/musicbrainz-scripts/raw/master/mb-edit-merge_from_acoustid.user.js";
        "MusicBrainz Quick Recording Match" =
          "https://github.com/Aerozol/metabrainz-userscripts/raw/main/MusicBrainz%20Quick%20Recording%20Match.user.js";
        "MASS MERGE RECORDINGS" =
          "https://github.com/jesus2099/konami-command/raw/master/mb_MASS-MERGE-RECORDINGS.user.js";
        "INLINE STUFF" = "https://github.com/jesus2099/konami-command/raw/master/mb_INLINE-STUFF.user.js";
        "REVIVE DELETED EDITORS" =
          "https://github.com/jesus2099/konami-command/raw/master/mb_REVIVE-DELETED-EDITORS.user.js";
      };
      link = name: url: "<li><a href=\"${url}\">${name}</a></li>";
    in
    ''
      <!doctype html>
      <meta charset="utf-8">
      <title>MusicBrainz userscripts</title>
      <h1>MusicBrainz userscripts</h1>
      <p>Click each one to install it in Violentmonkey.</p>
      <ul>
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList link scripts)}
      </ul>
    '';
}
