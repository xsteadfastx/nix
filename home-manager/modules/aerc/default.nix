{
  config,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
in
{
  # aerc config as Nix attrs, rendered to ini by home-manager's programs.aerc
  # (same shape as the iamb config in ../matrix.nix). The repo used to carry a
  # plain aerc.conf: upstream's default file is ~850 lines of commented-out
  # defaults wrapped around 14 live settings, so every edit meant diffing
  # against a file nobody had read twice. Sections below are aerc-config(5);
  # binds are aerc-binds(5); the styleset is aerc-stylesets(7).
  #
  # accounts.conf deliberately stays OUT of this module -- see the note on
  # home.file below.
  programs.aerc = {
    enable = true;
    package = pkgs.unstable.aerc;

    extraConfig = {
      ui = {
        # The styleset is written to ~/.config/aerc/stylesets by `stylesets`
        # below, which is already on aerc's default styleset search path; the
        # old `stylesets-dirs=~/.config/aerc` existed only because the file used
        # to sit loose at the top of the config dir.
        styleset-name = "dracula";
        # Threading client-side rather than trusting the server's THREAD
        # (aerc's upstream defaults, kept rather than dropped).
        threading-enabled = true;
        force-client-threads = true;
        threading-by-subject = true;
        # Ring the bell when mail arrives (aerc's default; explicit because
        # everything visual hangs off this BEL). The BEL goes aerc -> zellij ->
        # ghostty: zellij's visual_bell (see ../zellij) flashes the pane/tab
        # frame and feeds zjstatus's tab_bell_indicator, and ghostty's
        # bell-features handle the rest. The popup comes from the hook below,
        # not from the bell.
        new-message-bell = true;
      };

      # First matching filter wins, so these stay ordered most- to
      # least-specific. `html | colorize` and the rest are shell pipelines, run
      # from aerc's own filter path.
      filters = {
        "text/plain" = "colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        "text/html" = "html | colorize";
        # Only used for headers when [viewer] show-headers is on.
        ".headers" = "colorize";
      };

      hooks = {
        # New mail is announced through swaync (the session's
        # org.freedesktop.Notifications daemon) rather than the terminal bell
        # alone: notify-send comes from libnotify in ../swaync/default.nix and
        # reaches swaync over DBUS_SESSION_BUS_ADDRESS, so this works from any
        # zellij tab, focused or not.
        # Caveats from aerc-config(5): fires only for the folder aerc has
        # *selected* (mail arriving in another folder while you look elsewhere
        # is silent), and only while aerc runs -- its IMAP IDLE connection is
        # what notices the mail.
        mail-received = ''notify-send -a aerc "[$AERC_ACCOUNT/$AERC_FOLDER] New mail from $AERC_FROM_NAME" "$AERC_SUBJECT"'';
      };
    };

    # tmux-flavoured binds on top of aerc's defaults. `global` is the section
    # without a heading (aerc's own convention), hence the module's special
    # handling of it.
    extraBinds = {
      global = {
        "<C-p>" = ":prev-tab<Enter>";
        "<C-PgUp>" = ":prev-tab<Enter>";
        "<C-n>" = ":next-tab<Enter>";
        "<C-PgDn>" = ":next-tab<Enter>";
        "\\[t" = ":prev-tab<Enter>";
        "\\]t" = ":next-tab<Enter>";
        "<C-t>" = ":term<Enter>";
        "?" = ":help keys<Enter>";
        "<C-c>" = ":prompt 'Quit?' quit<Enter>";
        "<C-q>" = ":prompt 'Quit?' quit<Enter>";
        "<C-z>" = ":suspend<Enter>";
      };

      messages = {
        q = ":prompt 'Quit?' quit<Enter>";

        j = ":next<Enter>";
        "<Down>" = ":next<Enter>";
        "<C-d>" = ":next 50%<Enter>";
        "<C-f>" = ":next 100%<Enter>";
        "<PgDn>" = ":next 100%<Enter>";

        k = ":prev<Enter>";
        "<Up>" = ":prev<Enter>";
        "<C-u>" = ":prev 50%<Enter>";
        "<C-b>" = ":prev 100%<Enter>";
        "<PgUp>" = ":prev 100%<Enter>";
        g = ":select 0<Enter>";
        G = ":select -1<Enter>";

        J = ":next-folder<Enter>";
        "<C-Down>" = ":next-folder<Enter>";
        K = ":prev-folder<Enter>";
        "<C-Up>" = ":prev-folder<Enter>";
        H = ":collapse-folder<Enter>";
        "<C-Left>" = ":collapse-folder<Enter>";
        L = ":expand-folder<Enter>";
        "<C-Right>" = ":expand-folder<Enter>";

        v = ":mark -t<Enter>";
        "<Space>" = ":mark -t<Enter>:next<Enter>";
        V = ":mark -v<Enter>";

        T = ":toggle-threads<Enter>";
        zc = ":fold<Enter>";
        zo = ":unfold<Enter>";
        za = ":fold -t<Enter>";
        zM = ":fold -a<Enter>";
        zR = ":unfold -a<Enter>";
        "<tab>" = ":fold -t<Enter>";

        zz = ":align center<Enter>";
        zt = ":align top<Enter>";
        zb = ":align bottom<Enter>";

        "<Enter>" = ":view<Enter>";
        # was: d = :choose -o y 'Really delete this message' delete-message
        d = ":move [Gmail]/Trash<Enter>";
        a = ":archive flat<Enter>";
        A = ":unmark -a<Enter>:mark -T<Enter>:archive flat<Enter>";

        C = ":compose<Enter>";
        m = ":compose<Enter>";

        b = ":bounce<space>";

        rr = ":reply -a<Enter>";
        rq = ":reply -aq<Enter>";
        Rr = ":reply<Enter>";
        Rq = ":reply -q<Enter>";

        c = ":cf<space>";
        "$" = ":term<space>";
        "!" = ":term<space>";
        "|" = ":pipe<space>";

        "/" = ":search<space>";
        "\\" = ":filter<space>";
        n = ":next-result<Enter>";
        N = ":prev-result<Enter>";
        "<Esc>" = ":clear<Enter>";

        s = ":split<Enter>";
        S = ":vsplit<Enter>";

        pl = ":patch list<Enter>";
        pa = ":patch apply <Tab>";
        pd = ":patch drop <Tab>";
        pb = ":patch rebase<Enter>";
        pt = ":patch term<Enter>";
        ps = ":patch switch <Tab>";
      };

      # Drafts open in the composer instead of the pager.
      "messages:folder=Drafts" = {
        "<Enter>" = ":recall<Enter>";
      };

      view = {
        "/" = ":toggle-key-passthrough<Enter>/";
        q = ":close<Enter>";
        i = ":close<Enter>";
        O = ":open<Enter>";
        o = ":open<Enter>";
        S = ":save<space>";
        "|" = ":pipe<space>";
        D = ":delete<Enter>";
        A = ":archive flat<Enter>";

        "<C-l>" = ":open-link <space>";

        f = ":forward<Enter>";
        rr = ":reply -a<Enter>";
        rq = ":reply -aq<Enter>";
        Rr = ":reply<Enter>";
        Rq = ":reply -q<Enter>";

        H = ":toggle-headers<Enter>";
        "<C-k>" = ":prev-part<Enter>";
        "<C-Up>" = ":prev-part<Enter>";
        "<C-j>" = ":next-part<Enter>";
        "<C-Down>" = ":next-part<Enter>";
        J = ":next<Enter>";
        "<C-Right>" = ":next<Enter>";
        K = ":prev<Enter>";
        "<C-Left>" = ":prev<Enter>";
      };

      "view::passthrough" = {
        "$noinherit" = true;
        "$ex" = "<C-x>";
        "<Esc>" = ":toggle-key-passthrough<Enter>";
      };

      compose = {
        "$noinherit" = true;
        "$ex" = "<C-x>";
        "$complete" = "<C-o>";
        "<C-k>" = ":prev-field<Enter>";
        "<C-Up>" = ":prev-field<Enter>";
        "<C-j>" = ":next-field<Enter>";
        "<C-Down>" = ":next-field<Enter>";
        "<A-p>" = ":switch-account -p<Enter>";
        "<C-Left>" = ":switch-account -p<Enter>";
        "<A-n>" = ":switch-account -n<Enter>";
        "<C-Right>" = ":switch-account -n<Enter>";
        "<tab>" = ":next-field<Enter>";
        "<backtab>" = ":prev-field<Enter>";
        "<C-p>" = ":prev-tab<Enter>";
        "<C-PgUp>" = ":prev-tab<Enter>";
        "<C-n>" = ":next-tab<Enter>";
        "<C-PgDn>" = ":next-tab<Enter>";
      };

      "compose::editor" = {
        "$noinherit" = true;
        "$ex" = "<C-x>";
        "<C-k>" = ":prev-field<Enter>";
        "<C-Up>" = ":prev-field<Enter>";
        "<C-j>" = ":next-field<Enter>";
        "<C-Down>" = ":next-field<Enter>";
        "<C-p>" = ":prev-tab<Enter>";
        "<C-PgUp>" = ":prev-tab<Enter>";
        "<C-n>" = ":next-tab<Enter>";
        "<C-PgDn>" = ":next-tab<Enter>";
      };

      # Inline comments are the descriptions aerc prints on the review screen.
      "compose::review" = {
        y = ":send<Enter> # Send";
        n = ":abort<Enter> # Abort (discard message, no confirmation)";
        v = ":preview<Enter> # Preview message";
        p = ":postpone<Enter> # Postpone";
        q = ":choose -o d discard abort -o p postpone postpone<Enter> # Abort or postpone";
        e = ":edit<Enter> # Edit";
        a = ":attach<space> # Add attachment";
        d = ":detach<space> # Remove attachment";
      };

      terminal = {
        "$noinherit" = true;
        "$ex" = "<C-x>";

        "<C-p>" = ":prev-tab<Enter>";
        "<C-n>" = ":next-tab<Enter>";
        "<C-PgUp>" = ":prev-tab<Enter>";
        "<C-PgDn>" = ":next-tab<Enter>";
      };
    };

    # Ordered style rules, so this stays raw text: as attrs the keys would come
    # out alphabetised, and `*.default=true` (which resets styles) is not
    # order-independent of the specific rules around it.
    stylesets.dracula = ''
      #
      # aerc dracula styleset
      #
      # This styleset uses the terminal defaults as its fallback.
      # More information on how to configure the styleset can be found in
      # the aerc-stylesets(7) manpage. Please read the manual before
      # modifying or creating a styleset.
      #

      *.default=true

      default.bg=#20212b

      title.reverse=true
      header.bold=true
      header.fg=#8be9fd

      *error.bold=true
      error.fg=#ff5555
      warning.fg=#f1fa8c
      success.fg=#50fa7b

      statusline*.default=true
      statusline_default.reverse=true
      statusline_error.fg=#ff5555
      statusline_error.reverse=true
      statusline_default.fg=#303030
      statusline_default.bg=#af87ff

      dirlist_default.selected.fg=#f8f8f2
      dirlist_default.selected.bg=#44475a
      dirlist_recent.selected.fg=#44475a
      dirlist_recent.selected.bg=#f8f8f2
      dirlist_unread.fg=#50fa7b
      dirlist_unread.selected.fg=#50fa7b
      dirlist_unread.selected.bg=#44475a

      msglist_default.selected.fg=#44475a
      msglist_default.selected.bg=#f8f8f2
      msglist_unread.bold=true
      msglist_unread.fg=#50fa7b
      msglist_unread.selected.bg=#44475a
      msglist_read.selected.fg=#f8f8f2
      msglist_read.selected.bg=#44475a
      msglist_marked.fg=#f1fa8c
      msglist_marked.selected.fg=#f1fa8c
      msglist_marked.selected.bg=#44475a
      msglist_deleted.fg=#ff5555
      msglist_result.fg=#8be9fd
      msglist_result.selected.bg=#44475a

      msglist_deleted.selected.reverse=toggle

      completion_pill.reverse=true

      tab.reverse=true
      border.reverse = true
      tab.bg=#9c7adf
      tab.fg=#303030
      tab.selected.bg=#303030
      tab.selected.fg=#9c7adf
      border.fg=#20212b

      selector_focused.reverse=true
      selector_chooser.bold=true
    '';
  };

  # accounts.conf is the one file here that Nix does not render: aerc refuses to
  # start unless it is owner-only (its check is `mode & 077 == 0` -- measured:
  # 0400 and 0600 pass, 0644 is rejected with "too open permissions"), and a
  # store file is 0444. That is exactly why programs.aerc itself gives up and
  # tells you to set general.unsafe-accounts-conf = true.
  #
  # sops-nix instead decrypts it out of ../secrets.yaml (added once with
  # `sops set`, edited with `sops home-manager/secrets.yaml`) into
  # ~/.config/sops-nix/secrets/aerc-accounts.conf -- a real 0400 file -- and
  # symlinks the path below at it. aerc follows the symlink, sees 0400, and the
  # check stays enforced; unlike a store copy the account config is never
  # world-readable and never sits in the repo in the clear. The old mechanism
  # here (home.file + a `chmod 600` activation that dereferenced the store
  # symlink) satisfied the same check while leaving the identical bytes at 0444
  # in the store, so it bought nothing but moving parts.
  #
  # What it holds -- `sops -d --extract '["aerc-accounts.conf"]'
  # home-manager/secrets.yaml`: one [Personal] account, Gmail IMAP in, SMTP via
  # mail.your-server.de out, both credentials through `gopass show` commands
  # rather than inline secrets, Gmail Sent/All Mail roles, cache-headers on.
  sops.secrets."aerc-accounts.conf" = {
    path = "${home}/.config/aerc/accounts.conf";
  };
}
