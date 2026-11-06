{
  config,
  inputs,
  lib,
  nixosConfig,
  pkgs,
  ...
}:
let
  cfg = nixosConfig.features;
in
lib.mkIf cfg.desktop {
  programs.librewolf = {
    enable = true;

    # The source build (`librewolf-bin` is the prebuilt alternative), carrying
    # no Marionette/BiDi wrapper flags: those set navigator.webdriver = true on
    # every page, and Mozilla's own README warns that this "can trigger bot
    # detection on sites protected by Cloudflare, Akamai, etc." (2026-10-05:
    # Cloudflare cf-mitigated challenge loops ending in a block on
    # slapmagazine.com). The DevTools MCP drives its own instance off
    # librewolf-unwrapped instead -- see hosts/coltrane/coding-agent.nix.
    package = pkgs.librewolf;

    # No configPath: LibreWolf's own default (~/.librewolf) is what
    # librewolf.cfg points autoadmin.global_config_url at. Moving it under XDG
    # would leave that hook dangling and start a fresh, empty profile.

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
      # AIControls", Policies.sys.mjs. Restart the browser for it to take
      # effect; the schema marks it restart-required.
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
      # Only a default value for browser.download.dir -- the pref that actually
      # decides where downloads land is browser.download.folderList, and as long
      # as that stays 1 (Downloads) the directory is ignored: see the
      # folderList pref in Preferences below.
      DefaultDownloadDirectory = "\${home}/tmp";
      DisableFirefoxAccounts = true;
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
        # What makes DefaultDownloadDirectory above take effect.
        # DownloadIntegration.getPreferredDownloadsDirectory switches on this:
        # 0=Desktop, 1=Downloads folder, 2=the browser.download.dir folder,
        # 3=web app. The DefaultDownloadDirectory policy only sets the dir, so at
        # folderList=1 downloads still go to ~/Downloads. Object form on purpose:
        # a bare value would be setAndLockPref'd (Preferences policy), and this
        # one should stay changeable from Settings.
        "browser.download.folderList" = {
          Value = 2;
        };
        # Dark mode only where the site offers it: 0=dark, 1=light, 2=follow the
        # GTK/OS colour scheme, 3=follow the browser theme. This is what
        # Settings > Website appearance writes; locked here like the rest of
        # this block. Sites without a dark stylesheet keep their light look.
        "layout.css.prefers-color-scheme.content-override" = 0;
      };
      # Add-ons through Firefox's own policy, not home-manager's
      # `profiles.<p>.extensions.packages`: that route installs *unsigned* xpis,
      # which LibreWolf would load (`requireSigning = false`) but which then
      # never self-update. These come from AMO, so they are signed and
      # self-updating. `normal_installed` keeps them disableable in about:addons.
      ExtensionSettings =
        let
          amo = slug: {
            installation_mode = "normal_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
          };
        in
        {
          # Catppuccin Mocha with the mauve accent -- the same accent as the GTK
          # theme, Kvantum, icons and cursor. Published by the Catppuccin account
          # on AMO. (catppuccin/*'s firefox port is a Firefox Color theme: it
          # needs an extension and a click in Settings, so it cannot be set
          # declaratively -- this static theme can.)
          "{76aabc99-c1a8-4c1e-832b-d4f2941d5a7a}" = amo "catppuccin-mocha-mauve-git";
          "{c5867acc-54c9-4074-9574-04d8818d53e8}" = {
            installation_mode = "blocked";
          };
          # Violentmonkey, not Greasemonkey 4: the MusicBrainz script community
          # runs VM/TM, and GM4 dropped the sync GM_* APIs (GM_xmlhttpRequest)
          # that the importers rely on.
          "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = amo "violentmonkey";
          # The community fork (Guus), not AMO's "i-dont-care-about-cookies" —
          # that one is the Gen Digital/Avast-owned original.
          "idcac-pub@guus.ninja" = amo "istilldontcareaboutcookies";
          "uBlock0@raymondhill.net" = amo "ublock-origin";
          "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = amo "vimium-ff";
          # Slack gates huddles on the user agent: Firefox on Windows and macOS is
          # supported, Firefox on Linux is not — the "huddles aren't supported in
          # this browser" page is Slack's own UA check (webcompat/web-bugs#121309;
          # Chrome on Linux *is* supported). A Firefox-on-Windows UA keeps Slack on
          # the Firefox code path where huddles fully work, while a Chrome UA only
          # gets you joining with broken screen share. Firefox 158 no longer honours
          # per-site `general.useragent.override.<host>` prefs — only the global one
          # still applies (verified against a localhost UA echo, 2026-10) — so the
          # spoof has to live in an extension. One-time setup in its popup: tick
          # "Override per domain", add `app.slack.com`, and paste
          #   Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:158.0) Gecko/20100101 Firefox/158.0
          # (the bundled presets stop at Firefox ~57; keep the rv/version current
          # enough to stay above Slack's Firefox 131 floor).
          "user-agent-switcher@ninetailed.ninja" = amo "uaswitcher";
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
          # Dark Reader: replaced by the Catppuccin userstyles (userContent
          # below) plus the dark website appearance above. Left on, it would
          # recolour the already themed sites a second time.
          "addon@darkreader.org" = {
            installation_mode = "blocked";
          };
        };
    };

    profiles.default = {
      # Written to user.js, which is re-applied every start -- so anything set
      # here cannot be changed from the UI, on purpose.
      settings = {
        "browser.aboutConfig.showWarning" = false;
        # Actually *use* compact density: 0=normal, 1=compact, 2=touch. No
        # browser.compactmode.show here: that only reveals the density toggle in
        # Settings, and this pref is re-applied from user.js every start, so the
        # toggle could never stick anyway. Mostly toolbarbutton/urlbar spacing --
        # the tabs and toolbar rows stay.
        "browser.uidensity" = 1;
        "browser.tabs.tabMinWidth" = 30;
        "browser.tabs.tabClipWidth" = 60;
        "signon.rememberSignons" = false;
        # GPU canvas (the CanvasRenderer thread) was the biggest browser source of
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
        # userChrome.css and userContent.css are ignored without this.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # LibreWolf's own defaults are privacy-first in ways that change how the
        # session behaves. All of them are `defaultPref` in its mozilla.cfg
        # (overridable -- its ~20 `lockPref`s touch none of these), so this block
        # is the whole delta.
        #
        # Wipes cookies and site storage on every shutdown, so no login would
        # survive a restart.
        "privacy.sanitize.sanitizeOnShutdown" = false;
        "privacy.clearOnShutdown.offlineApps" = false;
        # UA/timezone/canvas/viewport spoofing. Slack's huddles are handled by
        # the UA-switcher policy above, not by RFP pretending to be Windows.
        "privacy.resistFingerprinting" = false;
        "webgl.disabled" = false;
        # webgl.disabled = false only clears Mozilla's switch. LibreWolf's
        # lw-permissions.patch also makes WebGL a *site permission*
        # (SitePermissions.sys.mjs, `webgl`), gated by librewolf.webgl.prompt --
        # default true, so a context is denied until granted for that site. That
        # gate stays, like the untouched media.eme.require-app-approval; turning
        # it off is what Settings calls "Always allow WebGL". What it must not do
        # is deny *silently*: with .hide there is no popup, getContext() returns
        # null and nothing is logged, so a page that builds its map first throws
        # in the constructor and looks exactly like the site being down
        # (2026-11-06, the eventortung kiosk). The URL-bar icon grants it.
        "librewolf.webgl.prompt.hide" = false;
        # Netflix/DRM. `media.gmp-manager.updateEnabled` is the switch no
        # "enable DRM" checkbox covers: LibreWolf turns the GMP *updater* off
        # (mozilla.cfg:403), so EME can be on and the Widevine CDM still never
        # installs -- about:addons sits at "will be installed shortly" forever.
        "media.gmp-manager.updateEnabled" = true;
        "media.eme.enabled" = true;
        "media.gmp-provider.enabled" = true;
        # LibreWolf sets this false (mozilla.cfg:418), so it is load-bearing.
        "media.gmp-widevinecdm.enabled" = true;
        # Same deal one line up in mozilla.cfg (:413): the OpenH264 codec GMP.
        # Settings calls it "Enable the OpenH264 plugin"; without it screen
        # sharing fails on sites that insist on H.264, Discord being the one
        # that bites. Rides on the same updater re-enabled above.
        "media.gmp-gmpopenh264.enabled" = true;
        # A no-op on 159 (it leaves Mozilla's default in place), but
        # librewolf.cfg on master points it at `data:text/plain,`, which would
        # silently un-enable the switches above.
        "media.gmp-manager.url" =
          "https://aus5.mozilla.org/update/3/GMP/%VERSION%/%BUILD_ID%/%BUILD_TARGET%/%LOCALE%/%CHANNEL%/%OS_VERSION%/%DISTRIBUTION%/%DISTRIBUTION_VERSION%/update.xml";
        # LibreWolf blocks all autoplay; Firefox's default is "allow". Set to 5
        # to keep LibreWolf's behaviour instead.
        "media.autoplay.default" = 0;
      };

      # Google AI Mode, declaratively. LibreWolf's build ships no search-config
      # dump, so its engine *names* are not resolvable -- the engine is described
      # here. `force` because Gecko rewrites search.json.mozlz4 on launch, so
      # engines added in the UI would vanish on the next switch.
      #
      # `udm=50` is AI Mode: google.com/aimode 301s to search?udm=50&aep=11
      # (verified 2026-11-06). Drop the udm param for classic results.
      search = {
        force = true;
        default = "google";
        engines.google = {
          name = "Google";
          urls = [
            {
              template = "https://www.google.com/search";
              params = [
                {
                  name = "udm";
                  value = "50";
                }
                {
                  name = "q";
                  value = "{searchTerms}";
                }
              ];
            }
          ];
          definedAliases = [ "@g" ];
        };
      };

      # Catppuccin's userstyles for ~140 sites, precompiled (Stylus not needed:
      # Gecko applies the `@-moz-document` blocks of userContent.css itself).
      # Read at startup only, so restart the browser after a switch. A derivation,
      # not a "${…}" string: home-manager writes any *string* here as the
      # file's text (`builtins.isString` -> `text`), so a store path string
      # ended up as the CSS itself.
      userContent = pkgs.callPackage ../../pkgs/catppuccin-userstyles {
        src = inputs.catppuccin-userstyles;
        inherit (config.catppuccin) flavor accent;
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

  # MusicBrainz userscripts. Gecko gives no way to put a script into a
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
