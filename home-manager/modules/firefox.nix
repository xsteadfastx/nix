{
  config,
  nixosConfig,
  pkgs,
  lib,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
  programs.firefox = {
    enable = true;
    # Deliberately the plain package: Marionette/BiDi set
    # navigator.webdriver = true on every page, and Mozilla's own README warns
    # that this "can trigger bot detection on sites protected by Cloudflare,
    # Akamai, etc." (2026-10-05: Cloudflare `cf-mitigated: challenge` loops that
    # end in a block on slapmagazine.com). The Firefox DevTools MCP therefore
    # launches its own Firefox in its own profile instead -- see
    # hosts/coltrane/coding-agent.nix (extra.firefox).
    package = pkgs.firefox;
    # home-manager 26.05 moved this default under XDG. Adopted 2026-10-05: the
    # profile was moved from ~/.mozilla/firefox to here at the same time (see
    # the commit message), and ~/.mozilla now only carries native-messaging-hosts.
    configPath = "${config.xdg.configHome}/mozilla/firefox";
    policies = {
      # Firefox's AI features, all of them: sidebar chatbot, link-preview key
      # points, smart tab groups, smart windows, on-device speech recognition,
      # PDF alt-text generation, translations. `Default` applies to every
      # feature unless a feature key overrides it, and Locked keeps a Nimbus
      # rollout from turning any of them back on. `Default` also lands on
      # browser.ai.control.default, which is what any feature not yet invented
      # falls back to (SpeechRecognitionFeature.sys.mjs, #resolvedControlState).
      #
      # This is the policy to use: the older GenerativeAI policy (same four
      # prefs, no translations/pdfAltText/speech) is *ignored* whenever
      # AIControls is present -- "Ignoring GenerativeAI policy in favor of
      # AIControls", Policies.sys.mjs. Restart Firefox for it to take effect;
      # the schema marks it restart-required.
      AIControls.Default = {
        Value = "blocked";
        Locked = true;
      };
      # Firefox 157 ships a profile-backup service that is *on* by default
      # (browser.backup.enabled = true) and, when its scheduler runs, walks the
      # profile's sqlite files page by page in the background
      # (sqlite.pages_per_step 50 / step_delay_ms 50) and retries up to 10 times
      # on failure. Those prefs sit in 157's Nimbus FeatureManifest, so a rollout
      # can turn automatic backups on with no user action.
      #
      # Off and locked, because two things make it worse than it looks:
      #  - the policy below only covers enabled/archive/restore, NOT
      #    scheduled.enabled (policies.sys.mjs:497), so the scheduler needs the
      #    extra locked pref further down;
      #  - per bug 2059450, browser.backup.enabled is only a lazy-load flag: any
      #    other BackupService.init() call (loading Settings -> Account and
      #    Sync, for instance) starts the service regardless of this policy.
      BrowserDataBackup = false;
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
        # Not covered by the BrowserDataBackup policy above (its handler locks
        # enabled/archive/restore only) and the pref a Nimbus rollout would flip
        # to make profile backups automatic. Locked, like the rest.
        "browser.backup.scheduled.enabled" = false;
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
        # GPU canvas (the CanvasRenderer thread) was the biggest Firefox source of
        # order-8/9 TTM allocations on xe; under fragmentation those feed the
        # kswapd -> xe shrinker -> rebind loop that lagged the whole desktop
        # (2026-10-05 trace). Kernel fix is 7.1.6+/7.1.8; ZFS pins us to 6.18.
        # Drop this once the kernel moves past that.
        "gfx.canvas.accelerated" = false;
        # Resume where you left off — clean quit, reboot (the session manager
        # sets resume_session_once on logout) and crash alike. 3 = "show my
        # windows and tabs from last time": SessionStartup then reports
        # RESUME_SESSION, which takes precedence over the crash path, so the
        # about:sessionrestore interstitial never appears. That is why
        # browser.sessionstore.resume_from_crash and max_resumed_crashes are
        # deliberately absent: both are only consulted when startup.page != 3.
        "browser.startup.page" = 3;
        # userChrome.css is ignored without this.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };
      # The "Show sidebar" launcher. No pref can turn it off: sidebar.revamp
      # injects it into the navbar's default placements, and removing it in the
      # UI would only live in browser.uiCustomization.state -- a blob user.js
      # re-applies on every start, which would wipe real toolbar customisations.
      # Firefox's own CSS hides this element with exactly this declaration.
      userChrome = ''
        #sidebar-button {
          display: none !important;
        }
      '';
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
